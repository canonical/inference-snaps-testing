# Inference Snaps testing

This repository contains Github workflows that test inference snaps on actual hardware, using Testflinger.

## Running the tests

Workflows are included for each inference snap.
These can be triggered from the **Actions** tab in the Github web UI.
The only required input is the store channel from where to install the snap to be tested.

Lower level workflows, called **Test chat** and **Test VLM**, are provided.
These can be used to run a specific test configuration on a specific Testflinger queue.

## Running the tests locally

### Prerequisites

* A Device Under Test (DUT) that can be accessed over the network using SSH. This can also be your localhost.
* SSH key authentication needs to be set up, as password authentication is not supported.

### Running the scripts

Test configurations are defined by the environment variables defined in `local-scripts/env.bash`.
Edit these values to reflect what should be tested and where it should run.

After setting the configuration, one can test chat functionality using:
```bash
bash local-scripts/local-test-text-prompt.bash
```
Or multimodal capabilities, using text and an image inputs, using:
```bash
bash local-scripts/local-test-multimodal-prompt.bash
```