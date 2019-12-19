(function (root, factory) {
  if (typeof define === 'function' && define.amd) {
    // AMD. Register as an anonymous module unless amdModuleId is set
    define('simple-pjax', ["jquery","simple-module","simple-url"], function (a0,b1,c2) {
      return (root['pjax'] = factory(a0,b1,c2));
    });
  } else if (typeof exports === 'object') {
    // Node. Does not work with strict CommonJS, but
    // only CommonJS-like environments that support module.exports,
    // like Node.
    module.exports = factory(require("jquery"),require("simple-module"),require("simple-url"));
  } else {
    root.simple = root.simple || {};
    root.simple['pjax'] = factory(root["jQuery"],root["SimpleModule"],root["simple.url"]);
  }
}(this, function ($, SimpleModule, simpleUrl) {

var Pjax, pjax,
  extend = function(child, parent) { for (var key in parent) { if (hasProp.call(parent, key)) child[key] = parent[key]; } function ctor() { this.constructor = child; } ctor.prototype = parent.prototype; child.prototype = new ctor(); child.__super__ = parent.prototype; return child; },
  hasProp = {}.hasOwnProperty;

Pjax = (function(superClass) {
  extend(Pjax, superClass);

  function Pjax() {
    return Pjax.__super__.constructor.apply(this, arguments);
  }

  Pjax.prototype.opts = {
    el: null,
    autoload: true,
    history: true,
    slowTime: 800,
    title: '{{ name }}',
    linkAttribute: 'data-pjax'
  };

  Pjax.prototype.supportHistory = !!(window.history && history.pushState);

  Pjax.pageCache = {};

  Pjax.prototype._init = function() {
    if (!this.supportHistory) {
      return;
    }
    this.el = this.opts.el ? $(this.opts.el) : $('body');
    this.el.addClass('simple-pjax');
    $(document).on('click', "a[" + this.opts.linkAttribute + "]", (function(_this) {
      return function(e) {
        var $link, url;
        e.preventDefault();
        $link = $(e.currentTarget);
        url = simple.url($link.attr('href'));
        if (url) {
          return _this.load(url, {
            nocache: $link.is("[" + _this.opts.linkAttribute + "-nocache]"),
            norefresh: $link.is("[" + _this.opts.linkAttribute + "-norefresh]")
          });
        }
      };
    })(this));
    this.on('pjaxunload', (function(_this) {
      return function(e, $page, page) {
        var $scrollContainer, selector;
        if (!page) {
          page = {};
        }
        if (!page.params) {
          page.params = {};
        }
        selector = $page.data('scroll-container-selector');
        $scrollContainer = selector ? $(selector) : $(document);
        if (!$scrollContainer.length) {
          $scrollContainer = $(document);
        }
        return $.extend(page.params, {
          scrollPosition: {
            top: $scrollContainer.scrollTop(),
            left: $scrollContainer.scrollLeft()
          }
        });
      };
    })(this));
    this.on('pjaxload', (function(_this) {
      return function(e, $page, page) {
        var promises, url;
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
            var $target, error, targetOffset;
            try {
              $target = $("#" + url.hash);
              if (!($target.length > 0)) {
                return;
              }
              targetOffset = $target.offset();
              return $(document).scrollTop(targetOffset.top - 30).scrollLeft(targetOffset.left - 30);
            } catch (_error) {
              error = _error;
            }
          }, 0);
        });
      };
    })(this));
    if (this.opts.history) {
      $(window).off('popstate.pjax').on('popstate.pjax', (function(_this) {
        return function(e) {
          var page, state;
          state = e.originalEvent.state;
          if (!state) {
            return;
          }
          if (_this.triggerHandler('pajxunload', [_this.el.children().first(), _this.getCache()]) === false) {
            return;
          }
          if (_this.request) {
            _this.request.abort();
            _this.request = null;
          }
          page = _this.getCache(state.url);
          if (!page) {
            return;
          }
          _this.el[0].innerHTML = page.html;
          _this.el[0].offsetHeight;
          _this.pageTitle(state.name);
          return _this.loadPage();
        };
      })(this));
    }
    if (this.opts.autoload) {
      return this.loadPage();
    }
  };

  Pjax.prototype.pageTitle = function(title) {
    var match, params, re;
    if (title) {
      title = this.opts.title.replace('{{ name }}', title);
      params = {
        pjax: this,
        title: title
      };
      $(document).triggerHandler('setpagetitle.pjax', [params]);
      title = params.title;
      if (document.title !== title) {
        document.title = title;
      }
    } else {
      title = document.title;
      params = {
        pjax: this,
        title: title
      };
      $(document).trigger('getpagetitle.pjax', [params]);
      re = new RegExp(this.opts.title.replace('{{ name }}', '(\\S+)'), 'g');
      match = re.exec(params.title);
      if (match) {
        title = match[1];
      }
    }
    return title;
  };

  Pjax.prototype.load = function(url, opts) {
    var $page, $scrollContainer, page, pageId, ref, selector, state;
    if (typeof url === 'string') {
      url = simple.url(url);
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
    if (page && !page.nocache && !opts.nocache) {
      this.el[0].innerHTML = page.html;
    } else {
      this.el.addClass('pjax-loading');
      this.slowTimer = setTimeout((function(_this) {
        return function() {
          _this.el.addClass('pjax-loading-slow');
          return _this.slowTimer = null;
        };
      })(this), this.opts.slowTime);
      page = {
        url: url.toString('relative'),
        name: document.title,
        html: ''
      };
    }
    state = $.extend({}, page, {
      html: ''
    });
    this.trigger('pushstate', [state]);
    history.pushState(state, state.name, state.url);
    this.pageTitle(this._t('loading'));
    this.el.height('');
    this.trigger('pjaxbeforeload', [page]);
    $page = this.el.children().first();
    if (opts.scrollPosition && ((ref = state.params) != null ? ref.scrollPosition : void 0)) {
      selector = $page.data('scroll-container-selector');
      $scrollContainer = selector ? $(selector) : $(document);
      if (!$scrollContainer.length) {
        $scrollContainer = $(document);
      }
      $scrollContainer.scrollTop(state.params.scrollPosition.top).scrollLeft(state.params.scrollPosition.left);
    } else {
      $(document).scrollTop(0).scrollLeft(0);
    }
    if (opts.norefresh && page) {
      pageId = $page.attr('id');
      if (pageId) {
        $(document).trigger('pjaxload#' + pageId, [$page, page]);
      }
      return this.trigger('pjaxload', [$page, page]);
    } else {
      return this.requestPage(page);
    }
  };

  Pjax.prototype.requestPage = function(page) {
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
      complete: (function(_this) {
        return function() {
          return _this.request = null;
        };
      })(this),
      error: (function(_this) {
        return function(xhr, status) {
          if (status === 'abort') {
            return;
          }
          _this.trigger('pjaxerror', [xhr]);
          page.html = xhr.responseText;
          _this.loadPage(page);
          return Pjax.clearCache(page.url);
        };
      })(this),
      success: (function(_this) {
        return function(result, status, xhr) {
          var originUrl, pageUrl;
          page.html = $.trim(result);
          page.name = '';
          if (pageUrl = xhr.getResponseHeader('X-PJAX-URL')) {
            originUrl = simple.url(page.url);
            pageUrl = simple.url(pageUrl);
            if (!pageUrl.hash) {
              pageUrl.hash = originUrl.hash;
            }
            page.url = pageUrl.toString('relative');
          }
          return _this.loadPage(page, xhr);
        };
      })(this)
    });
  };

  Pjax.prototype.loadPage = function(page, xhr) {
    var $page, error, pageId, state, title;
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
      if ($page && !page.name) {
        page.name = $page.data('page-name');
      }
    } else {
      $page = this.el.children().first();
      page = {
        url: simple.url().toString('relative'),
        name: $page.data('page-name') || this.pageTitle(),
        html: this.el.html()
      };
    }
    this.url = simple.url(page.url);
    this.setCache(page);
    state = $.extend({}, page, {
      html: ''
    });
    this.trigger('replacestate', [state]);
    title = this.pageTitle(state.name);
    history.replaceState(state, title, state.url);
    this.el.height('');
    pageId = $page.attr('id');
    if (pageId) {
      $(document).trigger('pjaxload#' + pageId, [$page, page]);
    }
    return this.trigger('pjaxload', [$page, page, xhr]);
  };

  Pjax.prototype.unload = function() {
    var page, state, title;
    if (this.url) {
      page = this.setCache();
    }
    if (this.triggerHandler('pjaxunload', [this.el.children().first(), page]) === false) {
      return false;
    }
    if (page) {
      page.html = this.el.html();
      this.setCache(page);
      state = $.extend({}, page, {
        html: ''
      });
      this.trigger('replacestate', [state]);
      title = this.pageTitle(state.name);
      history.replaceState(state, title, state.url);
    }
    this.url = null;
    this.el.height(this.el.height());
    this.el.empty();
    return page;
  };

  Pjax.prototype.setCache = function(page) {
    var $page;
    if (this.el.hasClass('pjax-loading')) {
      return;
    }
    if (!page) {
      $page = this.el.children().first();
      page = {
        url: this.url.toString('relative'),
        name: $page.data('page-name') || this.pageTitle(),
        html: this.el.html(),
        nocache: $page.is("[" + this.opts.linkAttribute + "-nocache]")
      };
    }
    Pjax.pageCache[page.url] = page;
    return page;
  };

  Pjax.prototype.getCache = function(url) {
    var ref;
    if (url == null) {
      url = (ref = this.url) != null ? ref.toString('relative') : void 0;
    }
    if (url) {
      return Pjax.pageCache[url];
    } else {
      return null;
    }
  };

  Pjax.clearCache = function(url) {
    if (url) {
      if (typeof url === 'string') {
        url = simple.url(url).toString('relative');
      }
      return Pjax.pageCache[url] = void 0;
    } else {
      return Pjax.pageCache = {};
    }
  };

  Pjax.i18n = {
    'zh-CN': {
      loading: '正在加载'
    }
  };

  return Pjax;

})(SimpleModule);

pjax = function(opts) {
  return new Pjax(opts);
};

pjax.clearCache = Pjax.clearCache;

return pjax;

}));
