# User Stories

## As a user, I want to automatically capture screenshots at regular intervals so that I can maintain a visual record of my screen activity

### Scenarios
```gherkin
Scenario: Starting the screenshot automation
  Given I have the screenshot automation script
  When I start CCTV
  Then screenshots should be taken at the agreed interval
  And they should be saved in the agreed format and location

Scenario: Reviewing captured screenshots
  Given I have been running the screenshot automation
  When I open CCTV's storage folder
  Then I should see a series of timestamped screenshots
  And they should be in chronological order

Scenario: Checking the log file
  Given I have been running the screenshot automation
  When I check CCTV's capture status or error information
  Then I should see entries for each screenshot taken
  And I should see any errors that occurred during operation
```

### Usability Testing Tasks
1. Start CCTV and verify that screenshots are being taken
2. Open CCTV's storage folder and check that screenshots have useful timestamps
3. Stop CCTV and start it again, then verify that it behaves as expected

## As a user, I want the screenshot process to run in the background so that I can continue working without interruption

### Scenarios
```gherkin
Scenario: Running the script in the background
  Given CCTV is installed as an application
  When I launch the application
  Then screenshots should be taken automatically
  And the process should not interfere with my normal computer usage

Scenario: Script continues after system sleep
  Given the screenshot application is running
  When my computer goes to sleep and wakes up again
  Then the screenshot process should resume automatically
```

### Usability Testing Tasks
1. Install CCTV and, if required, add it to Login Items
2. Work normally on the computer for 30 minutes while the script runs
3. Put the computer to sleep for 5 minutes, then wake it and verify the script resumes
