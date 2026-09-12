package ide

import (
	"bytes"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"mime/multipart"
	"net/http"
	"net/textproto"
	"strconv"
	"strings"

	"github.com/kartFr/Asset-Reuploader/internal/app/config"
	"github.com/kartFr/Asset-Reuploader/internal/roblox"
)

var UploadAnimationErrors = struct {
	ErrNotLoggedIn       error
	ErrTokenInvalid      error
	ErrInappropriateName error
}{
	ErrNotLoggedIn:       errors.New("not logged in"),
	ErrTokenInvalid:      errors.New("XSRF token validation failed"),
	ErrInappropriateName: errors.New("inappropriate name or description"),
}

func uploadToRevival(c *roblox.Client, name, description string, data *bytes.Buffer) (int64, error) {
	domain := strings.TrimSpace(config.Get("domain"))
	if domain == "" {
		domain = "aisaka.me"
	}

	uploadURL := fmt.Sprintf("https://www.%s/develop/upload", domain)

	// Step 1: Probe to obtain fresh CSRF Token and CSRF Cookie
	probeReq, err := http.NewRequest("POST", uploadURL, bytes.NewReader([]byte("{}")))
	if err != nil {
		return 0, err
	}
	probeReq.Header.Set("User-Agent", "Mozilla/5.0 (Windows NT 10.0; Win64; x64)")
	probeReq.Header.Set("Content-Type", "application/json")

	probeResp, err := c.DoRequest(probeReq)
	if err != nil {
		return 0, fmt.Errorf("revival CSRF probe failed: %w", err)
	}
	csrfToken := probeResp.Header.Get("X-CSRF-Token")
	csrfCookie := probeResp.Header.Get("Set-Cookie")
	probeResp.Body.Close()

	if csrfToken == "" {
		csrfToken = probeResp.Header.Get("x-csrf-token")
	}

	// Step 2: Build Multipart Form Data matching Aisaka develop.js:
	// name, assetType (24 for animation), file
	var b bytes.Buffer
	w := multipart.NewWriter(&b)

	_ = w.WriteField("name", name)
	_ = w.WriteField("assetType", "24")
	if description != "" {
		_ = w.WriteField("description", description)
	}

	h := make(textproto.MIMEHeader)
	h.Set("Content-Disposition", fmt.Sprintf(`form-data; name="file"; filename="%s.rbxm"`, name))
	h.Set("Content-Type", "application/octet-stream")
	part, err := w.CreatePart(h)
	if err != nil {
		return 0, err
	}
	if _, err := part.Write(data.Bytes()); err != nil {
		return 0, err
	}
	_ = w.Close()

	// Step 3: POST Upload to Aisaka
	upReq, err := http.NewRequest("POST", uploadURL, &b)
	if err != nil {
		return 0, err
	}
	upReq.Header.Set("User-Agent", "Mozilla/5.0 (Windows NT 10.0; Win64; x64)")
	upReq.Header.Set("Content-Type", w.FormDataContentType())
	if csrfToken != "" {
		upReq.Header.Set("X-CSRF-Token", csrfToken)
	}

	cookieHeader := ""
	if csrfCookie != "" {
		cookieHeader = strings.Split(csrfCookie, ";")[0]
	}
	if c.Cookie != "" {
		if cookieHeader != "" {
			cookieHeader += "; "
		}
		cookieHeader += ".ROBLOSECURITY=" + c.Cookie
	}
	if cookieHeader != "" {
		upReq.Header.Set("Cookie", cookieHeader)
	}

	resp, err := c.DoRequest(upReq)
	if err != nil {
		return 0, err
	}
	defer resp.Body.Close()

	respBody, _ := io.ReadAll(resp.Body)
	respStr := strings.TrimSpace(string(respBody))

	if resp.StatusCode == http.StatusOK || resp.StatusCode == http.StatusCreated {
		var parsed map[string]interface{}
		if json.Unmarshal(respBody, &parsed) == nil {
			for _, k := range []string{"assetId", "id", "AssetId", "Id", "targetId", "TargetId"} {
				if v, ok := parsed[k]; ok {
					switch num := v.(type) {
					case float64:
						if int64(num) > 0 {
							return int64(num), nil
						}
					case string:
						if parsedID, err := strconv.ParseInt(num, 10, 64); err == nil && parsedID > 0 {
							return parsedID, nil
						}
					}
				}
			}
		}

		if id, parseErr := strconv.ParseInt(respStr, 10, 64); parseErr == nil && id > 0 {
			return id, nil
		}

		return 0, fmt.Errorf("revival upload succeeded but could not parse ID from: %s", respStr)
	}

	return 0, fmt.Errorf("revival upload returned %s: %s", resp.Status, respStr)
}

func NewUploadAnimationHandler(
	c *roblox.Client,
	name,
	description string,
	data *bytes.Buffer,
	groupID ...int64,
) (func() (int64, error), error) {
	var group int64
	if len(groupID) > 0 {
		group = groupID[0]
	}
	currentName := name

	domain := strings.TrimSpace(config.Get("domain"))
	if domain != "" && !strings.Contains(domain, "roblox.com") {
		return func() (int64, error) {
			return uploadToRevival(c, currentName, description, data)
		}, nil
	}

	return func() (int64, error) {
		req, err := newCreateAssetRequest(
			"Animation",
			currentName,
			description,
			data,
			"model/x-rbxm",
			func() int64 {
				if group > 0 {
					return group
				}
				return c.UserInfo.ID
			}(),
			group > 0,
		)
		if err != nil {
			return 0, err
		}

		id, err := executeCreateAsset(c, req, UploadAnimationErrors.ErrTokenInvalid, UploadAnimationErrors.ErrNotLoggedIn)
		if err == nil {
			return id, nil
		}

		if isInappropriateError(err.Error()) {
			currentName = "[Censored]"
			return 0, UploadAnimationErrors.ErrInappropriateName
		}

		return 0, err
	}, nil
}
