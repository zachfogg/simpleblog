bogart = require "bogart"
couchdb = require "couchdb"
dbConfig =
    user: "zach"
    password: "5984"

app = bogart.router (get, post, update, destroy) ->
    client     = couchdb.createClient 5984, "localhost", dbConfig
    db         = client.db "simpleblog"
    viewEngine = bogart.viewEngine "mustache"

    get '/', () ->
        bogart.html "Hello, node!"

    get "/posts/new", (request) ->
        viewEngine.respond "new-post.html", locals: title: 'New Post'

    get "/posts", (request) ->
        db.view("blog", "posts_by_date").then (response) ->
            posts = response.rows.map (x) -> x.value
            viewEngine.respond "posts.html",
                locals:
                    posts: posts
                    title: "simpleblog"

    post "/posts", (request) ->
        post = request.params
        post.type = "post"

        db.saveDoc(post).then (response) ->
            bogart.redirect "/posts"

    get "/posts/:id", (request) ->
        db.openDoc(request.params.id).then (post) ->
            viewEngine.respond "posts.html", locals: post

    post "/posts/:id/comments", (request) ->
            comment = req.params
            db.openDoc(comment.id).then (post) ->
                post.comments = post.comments or []
                post.comments.push(comment)

                db.saveDoc(post).then (response) ->
                    bogart.redirect "/posts/"+comment.id

app = bogart.middleware.ParseForm app
bogart.start app
