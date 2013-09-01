{Adapter,Robot,TextMessage,EnterMessage,LeaveMessage} = require 'hubot'

WebsocketClient = require('websocket').client
crypto = require('crypto')
_u     = require('underscore')

class PratBot extends Adapter
  prepare_query_string: (params) ->
    str = ""
    keys = Object.keys(params)
    keys = _u.sortBy(keys, (key) -> return key)
    str += [key, '=', params[key]].join('') for key in keys

  generateSignature: (secret, method, path, body, params) ->
    body = if not body? then "" else body
    signature = secret + method.toUpperCase() + path + @prepare_query_string(params) + body
    hash = crypto.createHash('sha256').update(signature).digest()
    b64 = (new Buffer(hash)).toString('base64').substring(0, 43)
    b64.replace(/\+/g, '-')
    b64.replace(/\//g, '_')

  run: ->
    API_KEY = "c4fb2d41-aa35-4c26-80a7-d258ddf5e6cd"
    SECRET = "c0b4c821-0225-4073-b2c5-ee553da74a32"
    expires = parseInt((new Date()).getTime()/1000) + 300
    params = { "api_key": API_KEY, "expires": expires.toString() }
    params.signature = @generateSignature(SECRET, "GET", "/eventhub", "", params)
    urlparams = []
    urlparams.push [prop, params[prop]].join('=') for prop of params
    @client = new WebsocketClient()
    @client.on 'connect', @.onConnect
    @client.connect 'ws://localhost:5000/eventhub?' + urlparams.join('&')

  onConnect: (connection) =>
    console.log('onConnect')
    connection.send("something")

    connection.on 'error', @onError
    connection.on 'message', @onMessage

  onError: (error) =>
    console.log("Connection Error: " + error.toString())

  onMessage: (message) =>
    console.log('onMessage')
    console.log(message)

    #user = @robot.brain.userForId message.data.user.username
    #user.room = message.data.channel

    #@receive new TextMessage(user, message)

  send: (envelope, messages...) ->
    console.log('sending')
    for msg in messages
      @robot.logger.debug "Sending to #{envelope.room}: #{msg}"

      @ws.send("something")

exports.use = (robot) ->
  new PratBot robot

