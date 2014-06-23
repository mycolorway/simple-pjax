# nodejs server for upload testing

express = require 'express'
app = express()
ect = require 'ect'

app.set 'view engine', 'ect'
app.set 'views', __dirname + '/views'
app.engine 'ect', ect({ watch: true, root: __dirname + '/views', ext : '.ect' }).render

app.use express.static(__dirname + '/../')

app.get '/', (req, res) ->
	res.render 'index', 
		pjax: !!req.param('pjax')

app.get '/page-2', (req, res) ->
	res.render 'page-2', 
		pjax: !!req.param('pjax')

app.get '/page-3', (req, res) ->
	res.render 'page-3',
		pjax: !!req.param('pjax')

module.exports = app


