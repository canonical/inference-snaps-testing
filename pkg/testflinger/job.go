package testflinger

import (
	"context"
	"fmt"
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
