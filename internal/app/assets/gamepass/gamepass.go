package gamepass

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
	"time"

	"github.com/kartFr/Asset-Reuploader/internal/app/config"
	"github.com/kartFr/Asset-Reuploader/internal/app/context"
	"github.com/kartFr/Asset-Reuploader/internal/app/request"
	"github.com/kartFr/Asset-Reuploader/internal/app/response"
	"github.com/kartFr/Asset-Reuploader/internal/color"
	"github.com/kartFr/Asset-Reuploader/internal/roblox"
)

// Fallback 150x150 solid golden gamepass badge PNG (encoded)
var fallbackGamepassPNG = []byte{
	0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D,
	0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x10, 0x00, 0x00, 0x00, 0x10,
	0x08, 0x02, 0x00, 0x00, 0x00, 0x90, 0x91, 0x68, 0x36, 0x00, 0x00, 0x00,
	0x1B, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0xF8, 0xCF, 0xC0, 0x00,
	0x02, 0xA1, 0x82, 0x05, 0x62, 0x81, 0x0B, 0xC4, 0x02, 0x17, 0x88, 0x05,
	0x2E, 0x10, 0x00, 0xE7, 0x50, 0x03, 0x11, 0xA4, 0x8F, 0x6A, 0xE2, 0x00,
	0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
}

type gamepassDetails struct {
	TargetID          int64  `json:"TargetId"`
	Name              string `json:"Name"`
	Description       string `json:"Description"`
	IconImageAssetID  int64  `json:"IconImageAssetId"`
}

type thumbResponse struct {
	Data []struct {
		TargetID int64  `json:"targetId"`
		State    string `json:"state"`
		ImageURL string `json:"imageUrl"`
	} `json:"data"`
}

func fetchGamepassInfo(client *http.Client, gamepassID int64) (string, []byte) {
	name := fmt.Sprintf("Gamepass %d", gamepassID)
	var imgData []byte

	// 1. Fetch details from economy.roblox.com
	detailsURL := fmt.Sprintf("https://economy.roblox.com/v1/game-passes/%d/details", gamepassID)
	req, err := http.NewRequest("GET", detailsURL, nil)
	if err == nil {
		req.Header.Set("User-Agent", "Mozilla/5.0")
		if resp, err := client.Do(req); err == nil {
			defer resp.Body.Close()
			if resp.StatusCode == http.StatusOK {
				var d gamepassDetails
				if json.NewDecoder(resp.Body).Decode(&d) == nil && d.Name != "" {
					name = d.Name
				}
			}
		}
	}

	// 2. Fetch thumbnail from thumbnails.roblox.com
	thumbURL := fmt.Sprintf("https://thumbnails.roblox.com/v1/game-passes?gamePassIds=%d&size=150x150&format=Png", gamepassID)
	tReq, err := http.NewRequest("GET", thumbURL, nil)
	if err == nil {
		tReq.Header.Set("User-Agent", "Mozilla/5.0")
		if tResp, err := client.Do(tReq); err == nil {
			defer tResp.Body.Close()
			if tResp.StatusCode == http.StatusOK {
				var tData thumbResponse
				if json.NewDecoder(tResp.Body).Decode(&tData) == nil && len(tData.Data) > 0 {
					imgURL := tData.Data[0].ImageURL
					if imgURL != "" && strings.HasPrefix(imgURL, "http") {
						if imgResp, err := client.Get(imgURL); err == nil {
							defer imgResp.Body.Close()
							if imgResp.StatusCode == http.StatusOK {
								b, _ := io.ReadAll(imgResp.Body)
								if len(b) > 0 {
									imgData = b
								}
							}
						}
					}
				}
			}
		}
	}

	if len(imgData) == 0 {
		imgData = fallbackGamepassPNG
	}

	return name, imgData
}

func uploadTShirtToOctane(c *roblox.Client, name string, imgData []byte, groupID int64) (int64, error) {
	domain := strings.TrimSpace(config.Get("domain"))
	if domain == "" {
		domain = "octane.wtf"
	}

	uploadURL := fmt.Sprintf("https://%s/develop/upload", strings.TrimPrefix(domain, "www."))
	if groupID > 0 {
		uploadURL = fmt.Sprintf("https://%s/develop/upload?groupId=%d", strings.TrimPrefix(domain, "www."), groupID)
	}

	for attempt := 1; attempt <= 3; attempt++ {
		// Step 1: Probe for CSRF
		probeReq, err := http.NewRequest("POST", uploadURL, bytes.NewReader([]byte("{}")))
		if err != nil {
			return 0, err
		}
		probeReq.Header.Set("User-Agent", "Mozilla/5.0 (Windows NT 10.0; Win64; x64)")
		probeReq.Header.Set("Content-Type", "application/json")

		probeResp, err := c.DoRequest(probeReq)
		if err != nil {
			return 0, fmt.Errorf("Octane CSRF probe failed: %w", err)
		}
		csrfToken := probeResp.Header.Get("X-CSRF-Token")
		if csrfToken == "" {
			csrfToken = probeResp.Header.Get("x-csrf-token")
		}
		csrfCookie := probeResp.Header.Get("Set-Cookie")
		probeResp.Body.Close()

		// Step 2: Build multipart form data for T-Shirt (assetType = 2)
		var b bytes.Buffer
		w := multipart.NewWriter(&b)

		_ = w.WriteField("name", name)
		_ = w.WriteField("assetType", "2") // 2 = T-Shirt on Octane develop?View=2
		if groupID > 0 {
			_ = w.WriteField("groupId", strconv.FormatInt(groupID, 10))
			_ = w.WriteField("targetId", strconv.FormatInt(groupID, 10))
		}

		h := make(textproto.MIMEHeader)
		h.Set("Content-Disposition", fmt.Sprintf(`form-data; name="file"; filename="%s.png"`, name))
		h.Set("Content-Type", "image/png")
		part, err := w.CreatePart(h)
		if err != nil {
			return 0, err
		}
		if _, err := part.Write(imgData); err != nil {
			return 0, err
		}
		_ = w.Close()

		// Step 3: Send POST upload
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

		body, _ := io.ReadAll(resp.Body)
		bodyStr := strings.TrimSpace(string(body))

		if resp.StatusCode == http.StatusTooManyRequests || strings.Contains(strings.ToLower(bodyStr), "too many") {
			fmt.Printf("Rate limit hit on Octane for '%s'. Backing off for 4s (attempt %d/3)...\n", name, attempt)
			time.Sleep(4 * time.Second)
			continue
		}

		if resp.StatusCode == http.StatusOK || resp.StatusCode == http.StatusCreated {
			var parsed map[string]interface{}
			if json.Unmarshal(body, &parsed) == nil {
				for _, k := range []string{"assetId", "id", "AssetId", "Id", "targetId", "TargetId"} {
					if v, ok := parsed[k]; ok {
						switch num := v.(type) {
						case float64:
							if int64(num) > 0 {
								return int64(num), nil
							}
						case string:
							if pID, err := strconv.ParseInt(num, 10, 64); err == nil && pID > 0 {
								return pID, nil
							}
						}
					}
				}
			}

			if id, parseErr := strconv.ParseInt(bodyStr, 10, 64); parseErr == nil && id > 0 {
				return id, nil
			}
			return 0, fmt.Errorf("unexpected upload response: %s", bodyStr)
		}

		return 0, fmt.Errorf("upload returned %s: %s", resp.Status, bodyStr)
	}

	return 0, errors.New("exceeded maximum upload retries due to rate limiting")
}

func Reupload(ctx *context.Context, r *request.Request) {
	logger := ctx.Logger
	client := ctx.Client
	resp := ctx.Response

	logger.Println("Reuploading gamepasses as T-Shirts to Octane (develop?View=2)...")

	var groupID int64
	if r.IsGroup {
		groupID = r.CreatorID
	}
	if groupID == 0 {
		if cfgGroup := strings.TrimSpace(config.Get("group_id")); cfgGroup != "" {
			groupID, _ = strconv.ParseInt(cfgGroup, 10, 64)
		}
	}

	httpClient := &http.Client{Timeout: 15 * time.Second}
	total := len(r.IDs)

	for idx, gamepassID := range r.IDs {
		if idx > 0 {
			// Polite 1.2s delay between gamepass uploads to avoid rate limits
			time.Sleep(1200 * time.Millisecond)
		}
		name, imgBytes := fetchGamepassInfo(httpClient, gamepassID)
		targetDesc := "User"
		if groupID > 0 {
			targetDesc = fmt.Sprintf("Group %d", groupID)
		}
		fmt.Printf("[%d/%d] Uploading '%s' (%d) to Octane (%s)...\n", idx+1, total, name, gamepassID, targetDesc)

		newAssetID, err := uploadTShirtToOctane(client, name, imgBytes, groupID)
		if err != nil {
			color.Error.Println(fmt.Sprintf("[%d/%d] Failed to upload '%s' (%d): %v", idx+1, total, name, gamepassID, err))
			continue
		}

		color.Success.Println(fmt.Sprintf("[%d/%d] Successfully uploaded '%s'! New Octane T-Shirt ID: %d", idx+1, total, name, newAssetID))
		resp.AddItem(response.ResponseItem{
			OldID: gamepassID,
			NewID: newAssetID,
		})
	}

	logger.Println("Finished reuploading gamepasses as T-Shirts!")
}
