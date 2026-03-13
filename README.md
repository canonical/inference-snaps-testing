# inference-snaps-testing
## Testing on a local machine
### Prerequisites
- You need to have a DUT (Device Under Test) with SSH access.
- Password authentication is not supported, so you need to set up SSH keys for access.
### Running the scripts
Set the environment variables in the `local-scripts/env.bash`. Test results will be printed in the terminal.

```bash
bash local-scripts/local-test-text-prompt.bash
```
This will run the `local-test-text-prompt.bash` script, which will execute the text based prompt on the DUT and it will run a benchmark.

```bash
bash local-scripts/local-test-multimodal-prompt.bash
```
This will run the `local-test-multimodal-prompt.bash` script, which will execute the multimodal prompt on the DUT. 