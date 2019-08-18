# hubot-cron-commands

hubot-cron-commands adds a cronjob system to hubot to schedule commands to be run by hubot on a specific date and time.

based heavily on / forked from  miyagawa's hubot-cron.

## Installation

Add `hubot-cron-commands` to your package.json, run `npm install` and add hubot-cron to `external-scripts.json`.

Add hubot-cron to your `package.json` dependencies.

```
"dependencies": {
  "hubot-cron-commands": "^0.2.0"
}
```

Add `hubot-cron-commands` to `external-scripts.json`.

```
> cat external-scripts.json
> ["hubot-cron-commands"]
```

If you want to specify timezones, you'll need to install the [time](https://github.com/TooTallNate/node-time) module or place an entry for it in your package.json file.

    npm install time

## Usage

```
user> hubot new job "0 9 * * 1-5" "hubot echo Good morning everyone!"
hubot> Job 12345 created
...
hubot> Attempting to execute job 12345, crontab "0 9 * * 1-5" hubot echo Good morning everyone!
hubot> Good morning everyone!

user> hubot list jobs
hubot> (list of jobs)

user> hubot tz job 12345 America/Los_Angeles
hubot> Job 12345 updated to use America/Los_Angeles

user> hubot silence 12345
...
hubot> Good morning everyone!

user> hubot rm job 12345
hubot> Job 12345 removed
```

You can use any [node-cron](https://github.com/ncb000gt/node-cron) compatible crontab format to schedule messages. Registered message will be sent to the same channel where you created a job.

To persist the cron job in the hubot restart, you're recommended to use redis to persist Hubot brain.

Timezones are specified in [tzdata format](https://en.wikipedia.org/wiki/Tz_database#Examples).
