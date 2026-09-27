package request

import (
	"encoding/json"
	"strconv"
	"strings"

	"github.com/kartFr/Asset-Reuploader/internal/roblox"
	"github.com/kartFr/Asset-Reuploader/internal/roblox/games"
)

// FlexibleIDs safely unmarshals both numbers and strings (e.g. 12345 or "12345")
type FlexibleIDs []int64

func (f *FlexibleIDs) UnmarshalJSON(data []byte) error {
	var raw []interface{}
	if err := json.Unmarshal(data, &raw); err != nil {
		return err
	}

	result := make([]int64, 0, len(raw))
	for _, item := range raw {
		switch v := item.(type) {
		case float64:
			result = append(result, int64(v))
		case string:
			clean := strings.TrimSpace(v)
			if parsed, err := strconv.ParseInt(clean, 10, 64); err == nil {
				result = append(result, parsed)
			}
		}
	}
	*f = result
	return nil
}

type RawRequest struct {
	PlaceID         int64       `json:"placeId"`
	CreatorID       int64       `json:"creatorId"`
	IDs             FlexibleIDs `json:"ids"`
	DefaultPlaceIDs FlexibleIDs `json:"defaultPlaceIds"`
	PluginVersion   string      `json:"pluginVersion"`
	AssetType       string      `json:"assetType"`
	ExportJSON      bool        `json:"exportJSON"`
	IsGroup         bool        `json:"isGroup"`
}

type Request struct {
	UniverseID      int64
	PlaceID         int64
	CreatorID       int64
	IDs             []int64
	DefaultPlaceIDs []int64
	IsGroup         bool
}

func FromRawRequest(c *roblox.Client, req *RawRequest) (*Request, error) {
	placeID := req.PlaceID
	universeID := int64(0)

	placesInfo, err := games.MultiGetPlaceDetails(c, []int64{placeID})
	if err == nil && len(placesInfo) > 0 {
		universeID = placesInfo[0].UniverseID
	}

	return &Request{
		UniverseID:      universeID,
		PlaceID:         placeID,
		CreatorID:       req.CreatorID,
		IDs:             []int64(req.IDs),
		DefaultPlaceIDs: []int64(req.DefaultPlaceIDs),
		IsGroup:         req.IsGroup,
	}, nil
}
