package roblox

import (
	"encoding/json"
	"errors"
	"fmt"
	"net/http"
	"strings"

	"github.com/kartFr/Asset-Reuploader/internal/app/config"
	"github.com/kartFr/Asset-Reuploader/internal/retry"
)

var AuthenticateErrors = struct {
	ErrAuthorizationDenied error
}{
	ErrAuthorizationDenied: errors.New("invalid cookie"),
}

type UserInfo struct {
	ID          int64  `json:"id"`
	Username    string `json:"username"`
	DisplayName string `json:"displayName"`
}

func authenticateHandler(c *Client, cookie string) (func() (UserInfo, error), error) {
	domain := strings.TrimSpace(config.Get("domain"))
	if domain == "" {
		domain = "aisaka.me"
	}
	url := fmt.Sprintf("https://users.%s/v1/users/authenticated", domain)
	req, err := http.NewRequest("GET", url, http.NoBody)
	if err != nil {
		return func() (UserInfo, error) { return UserInfo{}, nil }, err
	}
	req.AddCookie(&http.Cookie{
		Name:  ".ROBLOSECURITY",
		Value: cookie,
	})

	return func() (UserInfo, error) {
		resp, err := c.DoRequest(req)
		if err == nil {
			defer resp.Body.Close()
			if resp.StatusCode == http.StatusOK {
				var userInfo UserInfo
				if err := json.NewDecoder(resp.Body).Decode(&userInfo); err == nil && userInfo.ID != 0 {
					return userInfo, nil
				}
			}
		}

		// Fallback for revivals where /v1/users/authenticated returns 500:
		userId := strings.TrimSpace(config.Get("user_id"))
		if userId != "" {
			userUrl := fmt.Sprintf("https://users.%s/v1/users/%s", domain, userId)
			uReq, uErr := http.NewRequest("GET", userUrl, http.NoBody)
			if uErr == nil {
				uResp, dErr := c.DoRequest(uReq)
				if dErr == nil {
					defer uResp.Body.Close()
					if uResp.StatusCode == http.StatusOK {
						var u UserInfo
						if err := json.NewDecoder(uResp.Body).Decode(&u); err == nil && u.ID != 0 {
							return u, nil
						}
					}
				}
			}
		}

		if resp != nil {
			if resp.StatusCode == http.StatusUnauthorized {
				return UserInfo{}, AuthenticateErrors.ErrAuthorizationDenied
			}
			return UserInfo{}, errors.New(resp.Status)
		}
		return UserInfo{}, errors.New("authentication failed")
	}, nil
}

func authenticate(c *Client, cookie string) (UserInfo, error) {
	handler, err := authenticateHandler(c, cookie)
	if err != nil {
		return UserInfo{}, nil
	}

	userInfo, err := retry.Do(
		retry.NewOptions(retry.Tries(3)),
		func(_ int) (UserInfo, error) {
			userInfo, err := handler()
			if err != nil {
				if err == AuthenticateErrors.ErrAuthorizationDenied {
					return UserInfo{}, &retry.ExitRetry{Err: err}
				}

				return UserInfo{}, &retry.ContinueRetry{Err: err}
			}

			return userInfo, nil
		},
	)
	return userInfo, err
}
