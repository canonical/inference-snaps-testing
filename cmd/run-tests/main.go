package main

import (
	"context"
	"fmt"
	"os"
	"path/filepath"
	"time"

	"github.com/jpmeijers/inference-snaps-testing/pkg/testflinger"
	"go.yaml.in/yaml/v4"
)

/*
   #!/bin/bash -eu

   # These vars are replaced by envsubst in the caller. Either in run.sh or the Github workflow.
   export SNAP_NAME=$SNAP_NAME
   export SNAP_CHANNEL=$SNAP_CHANNEL
   export EXPECTED_ENGINE=$EXPECTED_ENGINE
   export EXPECTED_TPS=$EXPECTED_TPS
   export INSTALL_NVIDIA_DRIVER_VERSION=$INSTALL_NVIDIA_DRIVER_VERSION
   export SELECT_ENGINE=$SELECT_ENGINE

   exec attachments/test/agent.sh
*/

func getAPIBase() string {
	if server := os.Getenv("TESTFLINGER_SERVER"); server != "" {
		return server
	}
	return "https://testflinger.canonical.com"
}

func main() {
	ctx := context.Background()
	apiBase := getAPIBase()

	client, err := testflinger.NewClientWithResponses(apiBase)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Failed to create Testflinger client: %v\n", err)
		os.Exit(1)
	}

	// Load testflinger.yaml
	dir, err := os.Getwd()
	if err != nil {
		fmt.Fprintf(os.Stderr, "Failed to get working directory: %v\n", err)
		os.Exit(1)
	}
	yamlPath := filepath.Join(dir, "testflinger.yaml")
	yamlData, err := os.ReadFile(yamlPath)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Failed to read testflinger.yaml: %v\n", err)
		os.Exit(1)
	}

	// Parse YAML into tf.Job
	var job testflinger.Job
	if err := yaml.Unmarshal(yamlData, &job); err != nil {
		fmt.Fprintf(os.Stderr, "Failed to parse YAML: %v\n", err)
		os.Exit(1)
	}

	// Submit job
	jobID, err := testflinger.SubmitJob(ctx, client, job)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Failed to submit job: %v\n", err)
		os.Exit(1)
	}
	fmt.Printf("Job submitted with ID: %s\n", jobID)

	// Upload attachments

	// Poll job status and print logs
	err = PollStatusAndLogs(ctx, client, jobID)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error while polling job status: %v\n", err)
	}
}

func PollStatusAndLogs(ctx context.Context, client *testflinger.ClientWithResponses, jobID string) error {
	var lastLogLen int
	consecutiveErrors := 0
	for {
		status, err := testflinger.GetJobStatus(ctx, client, jobID)
		if err != nil {
			consecutiveErrors++
			if consecutiveErrors%3 == 0 {
				return fmt.Errorf("Warning: Failed to get job status: %v (attempt %d)\n", err, consecutiveErrors)
			}
			time.Sleep(5 * time.Second)
			continue
		}
		consecutiveErrors = 0

		logs, err := testflinger.GetJobLogs(ctx, client, jobID)
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
