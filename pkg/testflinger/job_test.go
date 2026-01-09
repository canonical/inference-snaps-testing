package testflinger

import (
	"context"
	"fmt"
	"testing"
	"time"
)

func TestSubmitJob(t *testing.T) {
	ctx := context.Background()

	client, err := NewClientWithResponses("https://testflinger.canonical.com")
	if err != nil {
		t.Fatalf("Failed to create Testflinger client: %v", err)
	}

	var job Job

	name := "test-job"
	job.Name = &name

	job.JobQueue = "maas-systemtests-amd64"

	var provisionData Job_ProvisionData
	err = provisionData.FromProvisionData(map[string]interface{}{
		"distro": "noble",
	})
	if err != nil {
		t.Fatalf("Failed to set provision data: %v", err)
	}
	//job.ProvisionData = &provisionData

	testCommands := "hostname\n"
	var testData TestData
	testData.TestCmds = &testCommands
	job.TestData = &testData

	jobID, err := SubmitJob(ctx, client, job)
	if err != nil {
		t.Fatalf("SubmitJob failed: %v", err)
	}

	if jobID == "" {
		t.Fatalf("Expected non-empty job ID")
	}
	t.Logf("Submitted job: %s", jobID)

	err = CancelJob(ctx, client, jobID)
	if err != nil {
		t.Fatalf("Failed to cancel job: %v", err)
	}

	err = pollStatusAndLogs(ctx, client, jobID)
	if err != nil {
		t.Fatalf("Error while polling job status and logs: %v", err)
	}
}

func pollStatusAndLogs(ctx context.Context, client *ClientWithResponses, jobID string) error {
	var lastLogLen int
	consecutiveErrors := 0
	for {
		status, err := GetJobStatus(ctx, client, jobID)
		if err != nil {
			consecutiveErrors++
			if consecutiveErrors%3 == 0 {
				return fmt.Errorf("Warning: Failed to get job status: %v (attempt %d)\n", err, consecutiveErrors)
			}
			time.Sleep(5 * time.Second)
			continue
		}
		consecutiveErrors = 0

		logs, err := GetJobLogs(ctx, client, jobID)
		if err != nil {
			return fmt.Errorf("Warning: Failed to get job logs: %v\n", err)
		} else if len(logs) > lastLogLen {
			newLogs := logs[lastLogLen:]
			fmt.Print(newLogs)
			if len(newLogs) > 0 && newLogs[len(newLogs)-1] != '\n' {
				fmt.Print("\n")
			}
			lastLogLen = len(logs)
		}

		if status == "complete" || status == "completed" || status == "cancelled" || status == "failed" {
			fmt.Printf("\nJob finished with state: %s\n", status)
			break
		}
		time.Sleep(5 * time.Second)
	}
	return nil
}
