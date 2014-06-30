(function() {
  var Pjax, _ref,
    __hasProp = {}.hasOwnProperty,
    __extends = function(child, parent) { for (var key in parent) { if (__hasProp.call(parent, key)) child[key] = parent[key]; } function ctor() { this.constructor = child; } ctor.prototype = parent.prototype; child.prototype = new ctor(); child.__super__ = parent.prototype; return child; };

  Pjax = (function(_super) {
    __extends(Pjax, _super);

    function Pjax() {
      _ref = Pjax.__super__.constructor.apply(this, arguments);
      return _ref;
    }

    Pjax.prototype.opts = {
      el: null,
      autoload: true,
      history: true,
      slowTime: 800
    };

    Pjax.prototype.supportHistory = !!(window.history && history.pushState);

    Pjax.pageCache = {};

    Pjax.prototype._init = function() {
      var _this = this;
      if (!this.supportHistory) {
        return;
      }
      this.el = this.opts.el ? $(this.opts.el) : $('body');
      this.el.addClass('simple-pjax');
      this.el.on('click', 'a[data-pjax]', function(e) {
        var $link, url;
        e.preventDefault();
        $link = $(e.currentTarget);
        url = simple.url($link.attr('href'));
        if (url) {
          return _this.load(url, {
            nocache: $link.is('[data-pjax-nocache]')
          });
        }
      });
      this.on('pjaxunload', function(e, page) {
        if (!page.params) {
          page.params = {};
        }
        return $.extend(page.params, {
          scrollPosition: {
            top: $(document).scrollTop(),
            left: $(document).scrollLeft()
          }
        });
      });
      this.on('pjaxload', function(e, $page, page) {
        var promises, url;
        if (page.params && page.params.scrollPosition) {
          $(document).scrollTop(page.params.scrollPosition.top).scrollLeft(page.params.scrollPosition.left);
        } else {
          $(document).scrollTop(0).scrollLeft(0);
        }
        if (!page.url) {
          return;
        }
        url = simple.url(page.url);
        if (!url.hash) {
          return;
        }
        promises = [];
        $page.find('img').each(function(i, img) {
          var $img, dfd;
          if (img.complete) {
            return;
          }
          $img = $(img);
          dfd = $.Deferred();
          $img.data('dfd', dfd).one('load', function() {
            dfd = $img.data('dfd');
            if (dfd) {
              dfd.resolve();
              return $img.removeData('dfd');
            }
          });
          return promises.push(dfd.promise());
        });
        return $.when.apply(_this, promises).done(function() {
          $page[0].offsetHeight;
          return setTimeout(function() {
            var $target, targetOffset;
            $target = $('#' + url.hash);
            targetOffset = $target.offset();
            return $(document).scrollTop(targetOffset.top - 30).scrollLeft(targetOffset.left - 30);
          }, 0);
        });
      });
      if (this.opts.history) {
        $(window).off('popstate.pjax').on('popstate.pjax', function(e) {
          var state;
          state = e.originalEvent.state;
          if (!state) {
            return;
          }
          if (_this.request) {
            _this.request.abort();
            _this.request = null;
          }
          _this.el.html(state.html);
          document.title = state.name;
          return _this.loadPage();
        });
      }
      if (this.opts.autoload) {
        if (history.state) {
          this.el.html(history.state.html);
          document.title = history.state.name;
        }
        return this.loadPage();
      }
    };

    Pjax.prototype.load = function(url, opts) {
      var page, state,
        _this = this;
      if (typeof url === 'string') {
        url = simple.url(url);
      }
      if (this.url && this.url.toString('relative') === url.toString('relative')) {
        return;
      }
      opts = $.extend({
        nocache: false
      }, opts);
      if (this.request) {
        this.request.abort();
        this.request = null;
      }
      if (this.url && this.unload() === false) {
        return false;
      }
      this.url = url;
      page = this.getCache();
      if (page && !opts.nocache) {
        this.el.html(page.html);
      } else {
        this.el.addClass('pjax-loading');
        this.slowTimer = setTimeout(function() {
          _this.el.addClass('pjax-loading-slow');
          return _this.slowTimer = null;
        }, this.opts.slowTime);
        page = {
          url: url.toString('relative'),
          name: this._i18n('loading'),
          html: ''
        };
      }
      state = $.extend({}, page);
      this.trigger('pushstate', [state]);
      history.pushState(state, state.name, state.url);
      document.title = state.name;
      return this.requestPage(page);
    };

    Pjax.prototype.requestPage = function(page) {
      var _this = this;
      return this.request = $.ajax({
        url: page.url,
        type: 'get',
        headers: {
          "X-PJAX": "true"
        },
        data: {
          pjax: 1
        },
        dataType: 'html',
        complete: function() {
          return _this.request = null;
        },
        error: function(xhr) {
          _this.trigger('pjaxerror', [xhr]);
          page.html = xhr.responseText;
          _this.loadPage(page);
          return _this.clearCache();
        },
        success: function(result) {
          page.html = $.trim(result);
          page.name = '';
          return _this.loadPage(page);
        }
      });
    };

    Pjax.prototype.loadPage = function(page) {
      var $page, error, pageId, state;
      if (page) {
        if (!page.url) {
          page.url = this.url.toString('relative');
        }
        try {
          $page = $(page.html);
        } catch (_error) {
          error = _error;
          $page = '';
        }
        if (this.slowTimer) {
          clearTimeout(this.slowTimer);
        }
        this.el.empty().append($page);
        this.el.removeClass('pjax-loading');
        this.el.removeClass('pjax-loading-slow');
        if (!page.name) {
          page.name = $page.data('page-name');
        }
      } else {
        page = {
          url: simple.url().toString('relative'),
          name: document.title,
          html: this.el.html()
        };
        $page = this.el.children().first();
      }
      this.url = simple.url(page.url);
      this.setCache(page);
      state = $.extend({}, page);
      this.trigger('replacestate', [state]);
      history.replaceState(state, state.name, state.url);
      document.title = state.name;
      pageId = $page.attr('id');
      this.trigger('pjaxload', [$page, page]);
      if (pageId) {
        return $(document).trigger('pjaxload#' + pageId, [$page, page]);
      }
    };

    Pjax.prototype.unload = function() {
      var page, state;
      if (this.url) {
        page = this.getCache();
      }
      if (this.triggerHandler('pjaxunload', [this.el.children().first(), page]) === false) {
        return false;
      }
      if (page) {
        this.setCache(page);
        state = $.extend({}, page);
        this.trigger('replacestate', [state]);
        history.replaceState(state, state.name, state.url);
        document.title = state.name;
      }
      this.url = null;
      return this.el.empty();
    };

    Pjax.prototype.setCache = function(page) {
      if (!page) {
        page = {
          url: this.url.toString('relative'),
          name: document.title,
          html: this.el.html()
        };
      }
      Pjax.pageCache[page.url] = page;
      return page;
    };

    Pjax.prototype.getCache = function() {
      return Pjax.pageCache[this.url.toString('relative')];
    };

    Pjax.prototype.clearCache = function() {
      return Pjax.pageCache[this.url.toString('relative')] = void 0;
    };

    Pjax.i18n = {
      'zh-CN': {
        loading: '正在加载'
      }
    };

    return Pjax;

  })(Widget);

  window.simple || (window.simple = {});

  simple.pjax = function(opts) {
    return new Pjax(opts);
  };

}).call(this);
