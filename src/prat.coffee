{Adapter,Robot,TextMessage,EnterMessage,LeaveMessage} = require 'hubot'

WebsocketClient = require('websocket').client
crypto     = require('crypto')
_u         = require('underscore')
SERVER_URL = 'ws://localhost:5000/eventhub'
API_KEY    = "API_KEY_HERE"    # DEV: c4fb2d41-aa35-4c26-80a7-d258ddf5e6cd
SECRET     = "SECRET_KEY_HERE" # DEV: c0b4c821-0225-4073-b2c5-ee553da74a32

class PratBot extends Adapter
  prepare_query_string: (params) ->
    str = ""
    keys = Object.keys(params)
    keys = _u.sortBy(keys, (key) -> return key)
    str += [key, '=', params[key]].join('') for key in keys
    return str

  generateSignature: (secret, method, path, body, params) ->
    body = if not body? then "" else body
    signature = secret + method.toUpperCase() + path + @prepare_query_string(params) + body
    hash = crypto.createHash('sha256').update(signature).digest()
    b64 = (new Buffer(hash)).toString('base64').substring(0, 43)
    b64 = b64.replace(/\+/g, '-').replace(/\//g, '_')
    b64 = b64.replace(/\//g, '_')

  run: ->
    expires = parseInt((new Date()).getTime()/1000) + 300
    params = { "api_key": API_KEY, "expires": expires.toString() }
    params.signature = @generateSignature(SECRET, "GET", "/eventhub", "", params)
    urlparams = []
    urlparams.push [prop, params[prop]].join('=') for prop of params
    @client = new WebsocketClient()
    @client.on 'connect', @.onConnect
    @client.connect SERVER_URL + '?' + urlparams.join('&')

  onConnect: (connection) =>
    if !@connected
      @emit 'connected'
      @connected = true
    @connection = connection

    connection.on 'message', @onMessage
    connection.on 'error', @onError

  onError: (error) =>
    console.log("Connection Error: " + error.toString())

  onMessage: (message) =>
    msg = JSON.parse(message.utf8Data)
    return unless msg.action == 'publish_message'
    msgText = @preprocessText msg.data.message
    channel = msg.data.channel
    user = @robot.brain.userForId msg.data.user.username
    user.room = msg.data.channel

    @receive new TextMessage user, msgText

  preprocessText: (str) ->
    result = str
    if match = str.match(/^\/img\s+(.*)/)
      result = "#{@robot.name} image me #{match[1]}"
    result

  send: (envelope, messages...) ->
    for msg in messages
      @robot.logger.debug "Sending to #{envelope.room}: #{msg}"

      outputJson =
        action: "publish_message"
        data:
          message: msg
          channel: envelope.room

      @connection.send(JSON.stringify(outputJson))

  reply: (envelope, messages...) ->
    for msg in messages
      @send envelope, "#{envelope.user.name}: #{msg}"

  close: ->
    # TODO: leave the chat
    console.log('close')

exports.use = (robot) ->
  new PratBot robot

