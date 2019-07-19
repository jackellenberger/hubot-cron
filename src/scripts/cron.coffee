# Description:
#   register cron jobs to schedule commands on the current channel
#
# Commands:
#   hubot new job "<crontab format>" <message> - Schedule a cron job to execute another hubot command
#   hubot new job "<crontab format>" tz=<timezone> <message> - Schedule a cron job to execute another hubot command with cron executing in $timestamp, e.g. America/Chicago
#   hubot list jobs - List current cron jobs running in the current channel
#   hubot list all jobs - List current cron jobs running in all channels
#   hubot remove job <id> - remove job
#   hubot timezone job <id> - Set the timezone of an existing cron job
#
# Author:
#   Jack Ellenberger <jellenberger@uchicago.edu> based on work by miyagawa

# Garbage try block to avoid instances where downstream hubot plugins aren't requiring hubot
# Taken from https://hubot.github.com/docs/adapters/development/#gotchas
try
  {Robot,Adapter,TextMessage,User,Response} = require 'hubot'
  cronJob = require('cron').CronJob
catch
  prequire = require('parent-require')
  {Robot,Adapter,TextMessage,User,Response} = prequire 'hubot'
  cronJob = prequire('cron').CronJob
JOBS = {}

module.exports = (robot) ->
  robot.brain.data._private.cronjob or= {}
  syncJobs robot

  robot.respond /(?:new|add) job (?:'|"|“)(.*?)(?:'|"|”) (?:(?:tz=|timezone=)([_\/A-z]*))? ?(.*)$/i, (context) ->
    syncJobs robot
    handleNewJob robot, context, context.match[1], context.match[3], (context.match[2] || "America/Chicago")

  robot.respond /(?:list|ls) jobs?/i, (context) ->
    syncJobs robot
    text = ''
    for id, job of JOBS
      room = job.user.reply_to || job.user.room
      if room == context.message.user.reply_to or room == context.message.user.room
        text += "#{id}: #{job.pattern} @#{room} \"#{job.message}\"\n"
    if text.length > 0 then context.send text else context.send "No jobs here, chief!"

  robot.respond /(?:list|ls) all jobs?/i, (context) ->
    syncJobs robot
    text = ''
    for id, job of JOBS
      room = job.user.reply_to || job.user.room
      text += "#{id}: #{job.pattern} @#{room} \"#{job.message}\"\n"
    if text.length > 0 then context.send text else context.send "No jobs anywhere, comrade"

  robot.respond /(?:rm|remove|del|delete) job (\d+)/i, (context) ->
    syncJobs robot
    if (id = context.match[1]) and unregisterJob(robot, id)
      context.send "Job #{id} deleted"
    else
      context.send "Job #{id} does not exist"

  robot.respond /(?:tz|timezone) job (\d+) (.*)/i, (context) ->
    syncJobs robot
    if (id = context.match[1]) and (timezone = context.match[2]) and updateJobTimezone(robot, id, timezone)
      context.send "Job #{id} updated to use #{timezone}"
    else
      context.send "Job #{id} does not exist"

class Job
  constructor: (id, pattern, user, message, timezone) ->
    @id = id
    @pattern = pattern
    # cloning user because adapter may touch it later
    clonedUser = {}
    clonedUser[k] = v for k,v of user
    @user = clonedUser
    @message = message
    @timezone = timezone

  start: (robot) ->
    @cronjob = new cronJob(@pattern, =>
      @executeCommand robot
    , null, false, @timezone)
    @cronjob.start()

  stop: ->
    @cronjob.stop()

  serialize: ->
    [@pattern, @user, @message, @timezone]

  sendMessage: (robot) ->
    envelope = user: @user, room: @user.room
    robot.send envelope, @message

  executeCommand: (robot) ->
    message = @message
    user = @user
    envelope = user: @user, room: @user.room
    robot.send envelope, "Attempting to executing job #{@id}, crontab `#{@pattern} #{@message}`"
    robot.listeners.forEach (listener) ->
      if match = message.match(listener.regex)
        textMessage = new TextMessage user, message
        newcontext = new Response robot, textMessage, match
        listener.callback newcontext

createNewJob = (robot, pattern, user, message, timezone) ->
  id = Math.floor(Math.random() * 1000000) while !id? || JOBS[id]
  job = registerNewJob robot, id, pattern, user, message, timezone
  robot.brain.data._private.cronjob[id] = job.serialize()
  id

registerNewJobFromBrain = (robot, id, pattern, user, message, timezone) ->
  # for jobs saved in v0.2.0..v0.2.2
  user = user.user if "user" of user
  registerNewJob(robot, id, pattern, user, message, timezone)

storeJobToBrain = (robot, id, job) ->
  robot.brain.data._private.cronjob[id] = job.serialize()

  envelope = user: job.user, room: job.user.room
  robot.send envelope, "Job #{id} stored in brain asynchronously"

registerNewJob = (robot, id, pattern, user, message, timezone) ->
  job = new Job(id, pattern, user, message, timezone)
  job.start(robot)
  JOBS[id] = job

unregisterJob = (robot, id)->
  if JOBS[id]
    JOBS[id].stop()
    delete robot.brain.data._private.cronjob[id]
    delete JOBS[id]
    return yes
  no

handleNewJob = (robot, context, pattern, message, timezone) ->
  try
    id = createNewJob robot, pattern, context.message.user, message, timezone
    context.send "Job #{id} created"
  catch error
    context.send "Error caught parsing crontab pattern: #{error}. See http://crontab.org/ for the syntax"

updateJobTimezone = (robot, id, timezone) ->
  if JOBS[id]
    JOBS[id].stop()
    JOBS[id].timezone = timezone
    robot.brain.data._private.cronjob[id] = JOBS[id].serialize()
    JOBS[id].start(robot)
    return yes
  no

syncJobs = (robot) ->
  nonCachedJobs = difference(robot.brain.data._private.cronjob, JOBS)
  for own id, job of nonCachedJobs
    registerNewJobFromBrain robot, id, job...

  nonStoredJobs = difference(JOBS, robot.brain.data._private.cronjob)
  for own id, job of nonStoredJobs
    storeJobToBrain robot, id, job

difference = (obj1, obj2) ->
  diff = {}
  for id, job of obj1
    diff[id] = job if id !of obj2
  return diff

