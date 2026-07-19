require_relative "db"
require_relative "models/article"
require_relative "models/comment"
require "roda"
require "rack/method_override"

# A minimal, idiomatic Roda + Sequel blog.
#
# Domain-identical to roundhouse's `real-blog` Rails fixture (Article has_many
# Comment) so the two can be diffed through the same IR / emitters. See README
# for the Rails <-> Roda/Sequel mapping and the deliberate seams this exercises.
class Blog < Roda
  # Browser forms can only POST; a hidden `_method` field carries the real verb
  # (PATCH/DELETE). This is the Roda-idiomatic equivalent of Rails' implicit
  # method override.
  use Rack::MethodOverride

  plugin :render, layout: "layout"   # ERB templates in views/, wrapped in layout.erb
  plugin :partials                   # partial("articles/article") -> views/articles/_article.erb
  plugin :h                          # h(str) HTML-escape helper for user data
  plugin :all_verbs                  # r.patch / r.delete (core Roda ships get/post only)
  plugin :sessions, secret: ENV.fetch("SESSION_SECRET") { "dev-secret-" + "0" * 53 }
  plugin :flash
  plugin :not_found do
    response.status = 404
    view "not_found"
  end

  route do |r|
    # GET / -> articles index (the app's root route)
    r.root do
      index
    end

    r.on "articles" do
      # Collection level: /articles
      r.is do
        r.get { index }

        # POST /articles
        r.post do
          @article = Article.new(article_params)
          if @article.valid?
            @article.save
            flash["notice"] = "Article was successfully created."
            r.redirect "/articles/#{@article.id}"
          else
            view "articles/new"
          end
        end
      end

      # GET /articles/new  (must be routed before the Integer matcher; "new" is
      # not an integer so order is not load-bearing, but read intent-first)
      r.get "new" do
        @article = Article.new
        view "articles/new"
      end

      # Member level: everything under /articles/:id
      #
      # SEAM 1 (shared interior state): @article is loaded once at this interior
      # node and consumed by every sub-branch (show, edit, update, destroy, and
      # the nested comments routes).
      #
      # SEAM 2 (response returned at an interior node): the not-found check halts
      # here, before any terminal matcher runs -- the routing-tree case the
      # naive "split each terminal block into a handler" model does not cover.
      r.on Integer do |id|
        @article = Article[id]           # id : Integer, guaranteed by the matcher
        unless @article
          response.status = 404
          response.write view("not_found")
          r.halt
        end

        r.is do
          r.get { view "articles/show" }

          # PATCH /articles/:id
          r.patch do
            @article.set(article_params)
            if @article.valid?
              @article.save
              flash["notice"] = "Article was successfully updated."
              r.redirect "/articles/#{@article.id}"
            else
              view "articles/edit"
            end
          end

          # DELETE /articles/:id
          r.delete do
            @article.destroy
            flash["notice"] = "Article was successfully destroyed."
            r.redirect "/articles"
          end
        end

        # GET /articles/:id/edit
        r.get "edit" do
          view "articles/edit"
        end

        # Nested comments under the already-loaded @article
        r.on "comments" do
          # POST /articles/:id/comments
          r.post do
            @comment = Comment.new(comment_params)
            @comment.article = @article
            if @comment.valid?
              @comment.save
              flash["notice"] = "Comment was successfully created."
            else
              flash["alert"] = "Could not create comment."
            end
            r.redirect "/articles/#{@article.id}"
          end

          # DELETE /articles/:id/comments/:comment_id
          r.delete Integer do |comment_id|
            comment = @article.comments_dataset.where(id: comment_id).first
            comment&.destroy
            flash["notice"] = "Comment was successfully deleted."
            r.redirect "/articles/#{@article.id}"
          end
        end
      end
    end
  end

  # --- actions shared across routes -------------------------------------------

  def index
    @articles = Article.eager(:comments).order(Sequel.desc(:created_at)).all
    view "articles/index"
  end

  # --- view helpers -----------------------------------------------------------

  def truncate(text, length: 100)
    text = text.to_s
    text.length > length ? "#{text[0, length]}…" : text
  end

  def pluralize(count, singular)
    "#{count} #{count == 1 ? singular : "#{singular}s"}"
  end

  private

  # Strong-parameters analog: an explicit allow-list, in plain Ruby. Sequel's
  # `set`/`new` assign every given column by default, so the slice IS the guard.
  def article_params
    (request.params["article"] || {}).slice("title", "body")
  end

  def comment_params
    (request.params["comment"] || {}).slice("commenter", "body")
  end
end
