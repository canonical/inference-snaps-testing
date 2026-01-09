package testflinger

import (
	"bytes"
	"context"
	"fmt"
	"io"
	"mime/multipart"
	"net/http"
	"os"
	"path/filepath"
	"strings"
)

func SubmitJob(ctx context.Context, client *ClientWithResponses, job Job) (string, error) {
	resp, err := client.PostV1JobWithResponse(ctx, job)
	if err != nil {
		return "", fmt.Errorf("Failed to submit job: %v\n", err)
	}
	if resp.StatusCode() != 200 || resp.JSON200 == nil {
		return "", fmt.Errorf("Job submission failed: %s\n%s\n", resp.Status(), string(resp.Body))
	}

	return resp.JSON200.JobId, nil
}

func GetJobStatus(ctx context.Context, client *ClientWithResponses, jobID string) (string, error) {
	resp, err := client.GetV1ResultJobIdWithResponse(ctx, jobID)
	if err != nil {
		return "", err
	}
	if resp.StatusCode() != 200 || resp.JSON200 == nil {
		return "", fmt.Errorf("failed to get job status: HTTP %d: %s", resp.StatusCode(), string(resp.Body))
	}
	if resp.JSON200.JobState == nil {
		return "", fmt.Errorf("job_state missing in response")
	}
	return *resp.JSON200.JobState, nil
}

func GetJobLogs(ctx context.Context, client *ClientWithResponses, jobID string) (string, error) {
	resp, err := client.GetV1ResultJobIdLogLogTypeWithResponse(ctx, jobID, "output")
	if err != nil {
		return "", err
	}
	if resp.StatusCode() != 200 || resp.JSON200 == nil {
		return "", fmt.Errorf("failed to get job logs: HTTP %d: %s", resp.StatusCode(), string(resp.Body))
	}

	var logContent strings.Builder
	if resp.JSON200.Output != nil {
		for _, phase := range []string{"reserve", "allocate", "setup", "provision", "firmware_update", "test", "cleanup"} {
			if phaseData, ok := (*resp.JSON200.Output)[phase]; ok {
				if phaseData.LogData != "" {
					if logContent.Len() > 0 {
						logContent.WriteString("\n")
					}
					logContent.WriteString(phaseData.LogData)
				}
			}
		}
	}
	return logContent.String(), nil
}

func CancelJob(ctx context.Context, client *ClientWithResponses, jobID string) error {
	resp, err := client.PostV1JobJobIdActionWithResponse(ctx, jobID, ActionIn{Action: Cancel})
	if err != nil {
		return fmt.Errorf("Failed to cancel job: %v\n", err)
	}
	if resp.StatusCode() != 200 {
		return fmt.Errorf("Job cancellation failed: %s\n%s\n", resp.Status(), string(resp.Body))
	}
	return nil
}

func UploadAttachment(ctx context.Context, client *ClientWithResponses, jobID string, filePath string) error {
	// Open the file to be uploaded
	file, err := os.Open(filePath)
	if err != nil {
		return fmt.Errorf("failed to open file: %v", err)
	}
	defer func() {
		if closeErr := file.Close(); closeErr != nil {
			// Log but don't return error for defer
		}
	}()

	// Create a multipart form with the file
	var body bytes.Buffer
	writer := multipart.NewWriter(&body)
	part, err := writer.CreateFormFile("file", filepath.Base(file.Name()))
	if err != nil {
		return fmt.Errorf("failed to create form file: %v", err)
	}
	_, err = io.Copy(part, file)
	if err != nil {
		return fmt.Errorf("failed to copy file: %v", err)
	}
	if err := writer.Close(); err != nil {
		return fmt.Errorf("failed to close multipart writer: %v", err)
	}

	// Get the underlying *Client from ClientWithResponses
	// ClientWithResponses embeds ClientInterface which is actually *Client
	baseClient, ok := interface{}(client.ClientInterface).(*Client)
	if !ok {
		return fmt.Errorf("failed to get underlying client")
	}

	// Create a new HTTP request with the multipart body
	req, err := http.NewRequestWithContext(ctx, "POST",
		baseClient.Server+"/v1/job/"+jobID+"/attachments",
		&body)
	if err != nil {
		return fmt.Errorf("failed to create request: %v", err)
	}

	// Set the Content-Type header to multipart/form-data with the boundary
	req.Header.Set("Content-Type", writer.FormDataContentType())

	// Execute the request
	resp, err := baseClient.Client.Do(req)
	if err != nil {
		return fmt.Errorf("failed to upload attachment: %v", err)
	}
	defer func() {
		if closeErr := resp.Body.Close(); closeErr != nil {
			// Log but don't return error for defer
		}
	}()

	// Check the response status
	if resp.StatusCode != http.StatusOK {
		respBody, _ := io.ReadAll(resp.Body)
		return fmt.Errorf("failed to upload attachment: HTTP %d: %s", resp.StatusCode, string(respBody))
	}

	return nil
}
