package main

import (
	"context"
	"fmt"
	"os"
	"strconv"
	"time"

	"github.com/jpmeijers/inference-snaps-testing/pkg/testflinger"
	"go.yaml.in/yaml/v4"
)

type TestConfig struct {
	JobQueue                   string                 `yaml:"job-queue"`
	ProvisionData              map[string]interface{} `yaml:"provision-data"`
	SnapName                   string                 `yaml:"snap-name"`
	SnapChannel                string                 `yaml:"snap-channel"`
	ExpectedEngine             string                 `yaml:"expected-engine"`
	SelectEngine               string                 `yaml:"select-engine"`
	ExpectedTps                int                    `yaml:"expected-tps"`
	InstallNvidiaDriverVersion string                 `yaml:"install-nvidia-driver-version"`
}

const (
	TestflingerServer = "https://testflinger.canonical.com"
)

func main() {
	if len(os.Args) < 2 {
		panic(fmt.Errorf("Usage: %s <test-config.yaml>\n", os.Args[0]))
	}

	configFile := os.Args[1]
	data, err := os.ReadFile(configFile)
	if err != nil {
		panic(fmt.Errorf("read config file: %v", err))
	}

	var config TestConfig
	err = yaml.Unmarshal(data, &config)
	if err != nil {
		panic(fmt.Errorf("parse config file: %v", err))
	}

	job, err := createJob(config)
	if err != nil {
		panic(fmt.Errorf("create job: %v", err))
	}

	ctx := context.Background()
	client, err := testflinger.NewClientWithResponses(TestflingerServer)
	if err != nil {
		panic(fmt.Errorf("create Testflinger client: %v", err))
	}

	jobId, err := submitJob(ctx, client, job)
	if err != nil {
		panic(fmt.Errorf("submit job: %v", err))
	}
	fmt.Printf("Submitted job: %s\n", jobId)

	logs, err := pollStatusAndLogs(ctx, client, jobId)
	if err != nil {
		panic(fmt.Errorf("error while polling job status and logs: %v", err))
	}

	status, err := testflinger.GetJobStatus(ctx, client, jobId)
	if err != nil {
		panic(fmt.Errorf("error getting job status: %v", err))
	}
	fmt.Printf("Final job status: %s\n", status)

	// TODO check logs for failure reason
	fmt.Printf("Total log length: %d\n", len(logs))

}

func createJob(config TestConfig) (*testflinger.Job, error) {
	var job testflinger.Job

	name := "test-chat"
	job.Name = &name

	job.JobQueue = config.JobQueue

	var provisionData testflinger.Job_ProvisionData
	err := provisionData.FromProvisionData(config.ProvisionData)
	if err != nil {
		return nil, fmt.Errorf("set provision data: %v", err)
	}
	job.ProvisionData = &provisionData

	scriptPath := "agent-scripts/test-chat.sh"
	scriptBytes, err := os.ReadFile(scriptPath)
	if err != nil {
		return nil, fmt.Errorf("read agent script: %v", err)
	}
	agentScript := string(scriptBytes)

	scriptHeader := fmt.Sprintf(`#!/bin/bash -eux

export SNAP_NAME=%s
export SNAP_CHANNEL=%s
export EXPECTED_ENGINE=%s
export SELECT_ENGINE=%s
export EXPECTED_TPS=%s
export INSTALL_NVIDIA_DRIVER_VERSION=%s
`,
		config.SnapName,
		config.SnapChannel,
		config.ExpectedEngine,
		config.SelectEngine,
		strconv.Itoa(config.ExpectedTps),
		config.InstallNvidiaDriverVersion,
	)

	agentScript = scriptHeader + "\n" + agentScript

	var testData testflinger.TestData
	testData.TestCmds = &agentScript
	job.TestData = &testData

	return &job, nil
}

func submitJob(ctx context.Context, client *testflinger.ClientWithResponses, job *testflinger.Job) (string, error) {
	if job == nil {
		return "", fmt.Errorf("job not set")
	}

	jobID, err := testflinger.SubmitJob(ctx, client, *job)
	if err != nil {
		return "", fmt.Errorf("SubmitJob: %v", err)
	}

	if jobID == "" {
		return "", fmt.Errorf("empty job ID")
	}

	return jobID, nil
}

func pollStatusAndLogs(ctx context.Context, client *testflinger.ClientWithResponses, jobID string) (string, error) {
	var lastLogLen int
	var lastLogs string
	consecutiveErrors := 0

	for {
		status, err := testflinger.GetJobStatus(ctx, client, jobID)
		if err != nil {
			consecutiveErrors++
			if consecutiveErrors%3 == 0 {
				return lastLogs, fmt.Errorf("Warning: Failed to get job status: %v (attempt %d)\n", err, consecutiveErrors)
			}
			time.Sleep(5 * time.Second)
			continue
		}
		consecutiveErrors = 0

		logs, err := testflinger.GetJobLogs(ctx, client, jobID)
		if err != nil {
			return lastLogs, fmt.Errorf("Warning: Failed to get job logs: %v\n", err)
		} else if len(logs) > lastLogLen {
			newLogs := logs[lastLogLen:]
			fmt.Print(newLogs)
			if len(newLogs) > 0 && newLogs[len(newLogs)-1] != '\n' {
				fmt.Print("\n")
			}
			lastLogLen = len(logs)
			lastLogs = logs
		}

		if status == "complete" || status == "completed" || status == "cancelled" || status == "failed" {
			fmt.Printf("\nJob finished with state: %s\n", status)
			break
		}
		time.Sleep(5 * time.Second)
	}
	return lastLogs, nil
}
