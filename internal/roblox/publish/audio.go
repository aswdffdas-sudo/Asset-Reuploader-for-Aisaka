package publish

import (
	"bytes"
	"encoding/base64"
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

var UploadAudioErrors = struct {
	ErrModerated        error
	ErrTokenInvalid     error
	ErrNotAuthenticated error
	ErrQuotaExceeded    error
}{
	ErrModerated:        errors.New("moderated name or description"),
	ErrTokenInvalid:     errors.New("XSRF token validation failed"),
	ErrNotAuthenticated: errors.New("user is not authenticated"),
	ErrQuotaExceeded:    errors.New("user audio limit exceeded"),
}

type uploadAudioRequest struct {
	Name              string  `json:"name"`
	File              string  `json:"file"`
	GroupID           int64   `json:"groupId,omitempty"`
	PaymentSource     string  `json:"paymentSource,omitempty"`
	EstimatedFileSize int64   `json:"estimatedFileSize"`
	EstimatedDuration float64 `json:"estimatedDuration"`
	AssetPrivacy      int32   `json:"assetPrivacy"`
}

type publishAudioResponse struct {
	ID        int64 `json:"Id"`
	Status    int   `json:"status"`
	Code      int   `json:"code"`
	Message   string `json:"message"`
	Errors    []struct {
		Code    int    `json:"code"`
		Message string `json:"message"`
	} `json:"errors"`
}

func newUploadAudioRequest(name string, data *bytes.Buffer, groupID ...int64) (*http.Request, error) {
	var buffer bytes.Buffer
	size := int64(data.Len())

	encoder := base64.NewEncoder(base64.StdEncoding, &buffer)
	if _, err := io.Copy(encoder, data); err != nil {
		return nil, err
	}
	if err := encoder.Close(); err != nil {
		return nil, err
	}

	body := uploadAudioRequest{
		Name:              name,
		File:              buffer.String(),
		EstimatedFileSize: size,
	}
	if len(groupID) > 0 {
		body.GroupID = groupID[0]
	}

	jsonBody, err := json.Marshal(body)
	if err != nil {
		return nil, err
	}

	req, err := http.NewRequest("POST", "https://publish.roblox.com/v1/audio", bytes.NewReader(jsonBody))
	if err != nil {
		return nil, err
	}
	req.Header.Set("User-Agent", "RobloxStudio/WinInet")
	req.Header.Set("Content-Type", "application/json")

	return req, nil
}

func uploadAudioToRevival(c *roblox.Client, name string, data *bytes.Buffer) (*publishAudioResponse, error) {
	domain := strings.TrimSpace(config.Get("domain"))
	if domain == "" {
		domain = "aisaka.me"
	}

	uploadURL := fmt.Sprintf("https://www.%s/develop/upload", domain)

	// Step 1: Probe for CSRF
	probeReq, err := http.NewRequest("POST", uploadURL, bytes.NewReader([]byte("{}")))
	if err != nil {
		return nil, err
	}
	probeReq.Header.Set("User-Agent", "Mozilla/5.0 (Windows NT 10.0; Win64; x64)")
	probeReq.Header.Set("Content-Type", "application/json")

	probeResp, err := c.DoRequest(probeReq)
	if err != nil {
		return nil, fmt.Errorf("Aisaka CSRF probe failed: %w", err)
	}
	csrfToken := probeResp.Header.Get("X-CSRF-Token")
	if csrfToken == "" {
		csrfToken = probeResp.Header.Get("x-csrf-token")
	}
	csrfCookie := probeResp.Header.Get("Set-Cookie")
	probeResp.Body.Close()

	// Step 2: Build multipart form data for Audio (assetType = 3)
	var b bytes.Buffer
	w := multipart.NewWriter(&b)

	_ = w.WriteField("name", name)
	_ = w.WriteField("assetType", "3") // 3 = Audio on Aisaka develop?View=3

	h := make(textproto.MIMEHeader)
	h.Set("Content-Disposition", fmt.Sprintf(`form-data; name="file"; filename="%s.mp3"`, name))
	h.Set("Content-Type", "audio/mpeg")
	part, err := w.CreatePart(h)
	if err != nil {
		return nil, err
	}
	if _, err := part.Write(data.Bytes()); err != nil {
		return nil, err
	}
	_ = w.Close()

	// Step 3: Send POST upload
	upReq, err := http.NewRequest("POST", uploadURL, &b)
	if err != nil {
		return nil, err
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
		return nil, err
	}
	defer resp.Body.Close()

	body, _ := io.ReadAll(resp.Body)
	bodyStr := strings.TrimSpace(string(body))

	if resp.StatusCode == http.StatusOK || resp.StatusCode == http.StatusCreated {
		var parsed map[string]interface{}
		if json.Unmarshal(body, &parsed) == nil {
			for _, k := range []string{"assetId", "id", "AssetId", "Id", "targetId", "TargetId"} {
				if v, ok := parsed[k]; ok {
					switch num := v.(type) {
					case float64:
						if int64(num) > 0 {
							return &publishAudioResponse{ID: int64(num)}, nil
						}
					case string:
						if pID, err := strconv.ParseInt(num, 10, 64); err == nil && pID > 0 {
							return &publishAudioResponse{ID: pID}, nil
						}
					}
				}
			}
		}

		if id, parseErr := strconv.ParseInt(bodyStr, 10, 64); parseErr == nil && id > 0 {
			return &publishAudioResponse{ID: id}, nil
		}
		return nil, fmt.Errorf("unexpected audio upload response: %s", bodyStr)
	}

	return nil, fmt.Errorf("audio upload returned %s: %s", resp.Status, bodyStr)
}

func NewUploadAudioHandler(c *roblox.Client, name string, data *bytes.Buffer, groupID ...int64) (func() (*publishAudioResponse, error), error) {
	domain := strings.TrimSpace(config.Get("domain"))
	if domain != "" && !strings.Contains(domain, "roblox.com") {
		return func() (*publishAudioResponse, error) {
			return uploadAudioToRevival(c, name, data)
		}, nil
	}

	req, err := newUploadAudioRequest(name, data, groupID...)
	if err != nil {
		return func() (*publishAudioResponse, error) { return nil, nil }, err
	}

	return func() (*publishAudioResponse, error) {
		req.AddCookie(&http.Cookie{
			Name:  ".ROBLOSECURITY",
			Value: c.Cookie,
		})
		req.Header.Set("x-csrf-token", c.GetToken())

		resp, err := c.DoRequest(req)
		if err != nil {
			return nil, err
		}
		defer resp.Body.Close()

		var response publishAudioResponse
		json.NewDecoder(resp.Body).Decode(&response)

		switch resp.StatusCode {
		case http.StatusOK:
			return &response, nil
		case http.StatusBadRequest:
			if response.Errors == nil {
				return nil, errors.New(response.Message)
			}
			return nil, errors.New(response.Errors[0].Message)
		case http.StatusUnauthorized:
			return nil, UploadAudioErrors.ErrNotAuthenticated
		case http.StatusForbidden:
			c.SetToken(resp.Header.Get("x-csrf-token"))
			return nil, UploadAudioErrors.ErrTokenInvalid
		case http.StatusTooManyRequests:
			return nil, UploadAudioErrors.ErrQuotaExceeded
		default:
			return nil, errors.New(resp.Status)
		}
	}, nil
}
