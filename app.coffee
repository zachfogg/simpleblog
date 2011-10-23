###
Dependencies
###
require.paths.push "./lib"

express        = require "express"
couchdb        = require "couchdb"
authenticUser  = require "simpleauth"
_              = require "underscore"
require "date-utils"

###
Config
###
app = express.createServer()
app.register '.coffee', require('coffeekup').adapters.express

app.configure ->
    app.set 'views', __dirname + '/views'
    app.set 'view engine', "coffee"
    app.use express.bodyParser()
    app.use express.methodOverride()
    app.use app.router
    app.use express.static __dirname + "/public"

app.configure "development", -> app.use express.errorHandler (dumbExceptions: true, showStack: true)

app.configure "production", -> app.use express.errorHandler()

client = couchdb.createClient 5984, "localhost", (user: "zach", password: "5984")
db     = client.db "simpleblog"

POST_LIMIT    = 5
COMMENT_LIMIT = 100

###
Routes
###
app.get '/', (req, res) ->
    res.render "index"

app.get "/posts/new", (req, res) ->
     res.render "new-post", (title: 'New Post')

app.get "/posts", (req, res) ->
    (db.view "blog", "posts_by_date").then (results) ->
        posts = results.rows

        posts = postPrerender posts
        res.render "posts", (title: "simpleblog", posts: posts)

postPrerender = (posts) ->
    if posts.length > POST_LIMIT
        posts = _(posts).last POST_LIMIT

    _(posts).reverse()
    _(posts).map (post) -> timeStamped post.value, DATE_FORMAT_MUSTACHE

app.get "/posts/page/:pageNumber", (req, res) ->
    pageNumber = parseInt req.params.pageNumber, 10
    (db.view "blog", "posts_by_date").then (results) ->
        posts = results.rows
        for i in [0...pageNumber - 1]
            posts = _(posts).difference _(posts).rest posts.length - POST_LIMIT

        posts = postPrerender posts
        res.render "posts", (title: "simpleblog", posts: posts, pageNumber: pageNumber)

app.post "/posts", (req, res) ->
    post = req.body
    console.log post

    post.type = "post"
    if validPost post
        db.saveDoc timeStamped post, DATE_FORMAT_COUCHDB

    res.redirect "/posts"

app.get "/posts/:id", (req, res) ->
    (db.openDoc req.params.id).then (post) ->
        console.log post
        res.render "post", post

app.post "/posts/:id/comment", (req, res) ->
    comment = req.body
    id = req.params.id
    console.log id
    (db.openDoc id).then (post) ->
        console.log post
        post.comments = post.comments or []
        if validComment comment
            post.comments.push timeStamped comment, DATE_FORMAT_COUCHDB

        (db.saveDoc post).then () ->
            res.redirect "/posts/"+id

validPost    = (post)    -> post.title and post.body
validComment = (comment) -> comment.author and comment.body

timeStamped = (o = {}, toFormat = (d) -> d) ->
    o.date = toFormat new Date o.date or new Date
    o
DATE_FORMAT_COUCHDB  = (d) -> d.toFormat "MM-DD-YYYY HH24:MI:SS"
DATE_FORMAT_MUSTACHE = (d) -> d.getMonthName() + d.toFormat " DD, YYYY - HH24:MI"

app.listen 8080