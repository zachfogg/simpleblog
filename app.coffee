require.paths.push "./lib"

bogart         =  require  "bogart"
couchdb        =  require  "couchdb"
authenticUser  =  require  "simpleauth"

dbConfig =
    user: "zach"
    password: "5984"

_ = require "underscore"
require "date-utils"

DATE_FORMAT_COUCHDB  = (d) -> d.toFormat "MM-DD-YYYY HH24:MI:SS"
DATE_FORMAT_MUSTACHE = (d) -> d.getMonthName() + d.toFormat " DD, YYYY - HH24:MI"

app = bogart.router (get, post, update, destroy) ->
    client     = couchdb.createClient 5984, "localhost", dbConfig
    db         = client.db "simpleblog"
    viewEngine = bogart.viewEngine "mustache"

    get '/', () ->
        bogart.html "Hello, node!"

    get "/posts/new", (request) ->
        viewEngine.respond "new-post.mustache", locals: title: 'New Post'

    get "/posts", (request) ->
       db.view("blog", "posts_by_date").then (response) ->
            posts = _(response.rows).chain()
            .map((post) -> timeStamped post.value, DATE_FORMAT_MUSTACHE
            #).sortBy((post) -> new Date post.date
            ).reverse()
            .value()

            viewEngine.respond "posts.mustache",
                    locals:
                        posts: posts
                        title: "simpleblog"

    post "/posts", (request) ->
        post = request.params
        post.type = "post"

        if validPost post
            db.saveDoc timeStamped post, DATE_FORMAT_COUCHDB

        bogart.redirect "/posts"

    get "/posts/:id", (request) ->
        db.openDoc(request.params.id).then (post) ->
            viewEngine.respond "post.mustache", locals: post

    post "/posts/:id/comment", (request) ->
        comment = request.params
        (db.openDoc comment.id).then (post) ->
            post.comments = post.comments or []
            if validComment comment
                post.comments.push timeStamped comment, DATE_FORMAT_COUCHDB

            (db.saveDoc post).then (response) ->
                bogart.redirect "/posts/"+comment.id

validPost    = (post)    -> post.title and post.body
validComment = (comment) -> comment.author and comment.body

timeStamped = (o = {}, toFormat = (d) -> d) ->
    o.date = toFormat new Date o.date or new Date
    o

app = bogart.middleware.ParseForm app
bogart.start app
