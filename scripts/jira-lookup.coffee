# Description:
#   Jira lookup when issues are heard
#
# Dependencies:
#   None
#
# Configuration:
#   HUBOT_JIRA_LOOKUP_USERNAME
#   HUBOT_JIRA_LOOKUP_PASSWORD
#   HUBOT_JIRA_LOOKUP_URL
#   HUBOT_JIRA_LOOKUP_IGNORE_USERS (optional, format: "user1|user2", default is "jira|github")
#
# Commands:
#   None
#
# Author:
#   Matthew Finlayson <matthew.finlayson@jivesoftware.com> (http://www.jivesoftware.com)
#   Benjamin Sherman  <benjamin@jivesoftware.com> (http://www.jivesoftware.com)
#   Dustin Miller <dustin@sharepointexperts.com> (http://sharepointexperience.com)

module.exports = (robot) ->

  ignored_users = process.env.HUBOT_JIRA_LOOKUP_IGNORE_USERS
  if ignored_users == undefined
    ignored_users = "jira|github"

  robot.hear /\b[a-zA-Z]{2,5}-[0-9]{1,5}\b/, (msg) ->

    return if msg.message.user.name.match(new RegExp(ignored_users, "gi"))

    issue = msg.match[0]
    user = process.env.HUBOT_JIRA_LOOKUP_USERNAME
    pass = process.env.HUBOT_JIRA_LOOKUP_PASSWORD
    url = process.env.HUBOT_JIRA_LOOKUP_URL
    auth = 'Basic ' + new Buffer(user + ':' + pass).toString('base64')
    robot.http("#{url}/rest/api/latest/issue/#{issue}")
      .headers(Authorization: auth, Accept: 'application/json')
      .get() (err, res, body) ->
        try
          json = JSON.parse(body)
          if json.fields.summary
            unless json.fields.summary is null or json.fields.summary.nil? or json.fields.summary.empty?
              json_summary = json.fields.summary
          if json.fields.description
            unless json.fields.description is null or json.fields.description.nil? or json.fields.description.empty?
              desc_array = json.fields.description.split("\n")
              json_description = ""
              for item in desc_array[0..2]
                json_description += item
          if json.fields.assignee
            unless json.fields.assignee is null or json.fields.assignee.nil? or json.fields.assignee.empty?
              unless json.fields.assignee.name.nil? or json.fields.assignee.name.empty?
                json_assignee = json.fields.assignee.name
          if json.fields.status
            unless json.fields.status is null or json.fields.status.nil? or json.fields.status.empty?
              unless json.fields.status.name.nil? or json.fields.status.name.empty?
                json_status = json.fields.status.name
          if json.fields.components     
            unless json.fields.components is null or json.fields.components.nil? or json.fields.components.empty?
              json_components = (item.description for item in json.fields.components).join(", ")

          fallback = 'Issue:       #{json.key}: #{if json_summary? then json_summary}#{if json_description? then json_description}#{if json_assignee? then json_assignee}#{if json_status? then json_status}\n Link:        #{process.env.HUBOT_JIRA_LOOKUP_URL}/browse/#{json.key}\n'
          if process.env.HUBOT_SLACK_INCOMING_WEBHOOK?

            fields = []

            if json_components?.length then fields.push {
              title: 'Components'
              value: json_components
              short: true
            }

            if json_status?.length then fields.push {
              title: 'Status'
              value: json_status
              short: true
            } 

            if json_assignee?.length then fields.push {
              title: 'Assignee'
              value: json_assignee
              short: true
            }

            colorName = json?.fields?.status?.statusCategory?.colorName

            color = if colorName == 'yellow' then "#ffd351" 
            else if colorName == 'blueGray' then "#4a6785" 
            else if colorName == 'green' then "#14892c" 
            else '#aaa'

            robot.emit 'slack.attachment',
              message: msg.message
              content:
                title: "#{json.key} - #{json_summary}"
                title_link: "#{process.env.HUBOT_JIRA_LOOKUP_URL}/browse/#{json.key}"
                fallback: fallback
                fields: fields
                text: json.fields.description
                author_name: "@#{json.fields.reporter?.name}"
                author_icon: json.fields.reporter?.avatarUrls?["16x16"]
                color: color
          else
            msg.send fallback
        catch error
          console.log "Issue #{json.key} not found: #{error}"
