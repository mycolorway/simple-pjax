
class Pjax extends Widget

  opts:
    el: null
    autoload: true
    history: true

  supportHistory: !!(window.history && history.pushState)

  @pageCache: {}

  _init: ->
    return unless @supportHistory

    @el = if @opts.el then $(@opts.el) else $('body')

    @el.on 'click', 'a[data-pjax]', (e) =>
      e.preventDefault()
      $link = $(e.currentTarget)
      url = simple.url $link.attr 'href'

      if url
        @load url, 
          nocache: $link.is '[data-pjax-nocache]'

    @on 'pjaxunload', (e, page) =>
      page.params = {} unless page.params
      $.extend page.params,
        scrollPosition:
          top: $(document).scrollTop()
          left: $(document).scrollLeft()

    @on 'pjaxload', (e, $page, page) =>
      if page.params and page.params.scrollPosition
        $(document).scrollTop(page.params.scrollPosition.top)
          .scrollLeft(page.params.scrollPosition.left)
      else
        $(document).scrollTop(0)
          .scrollLeft(0)

      return unless page.url
      url = simple.url page.url
      return unless url.hash

      $target = $('#' + url.hash)
      targetOffset = $target.offset()
      $(document).scrollTop(targetOffset.top - 30)
        .scrollLeft(targetOffset.left - 30)


    if @opts.history
      @on 'pushstate.pjax', (e, state) =>
        history.pushState state, state.name, state.url

      @on 'replacestate.pjax', (e, state) =>
        history.replaceState state, state.name, state.url

      $(window).off('popstate.pjax').on 'popstate.pjax', (e) =>
        state = e.originalEvent.state
        return unless state

        if @request
          @request.abort()
          @request = null

        @el.html state.html
        document.title = state.name
        @requestPage state

    if @opts.autoload
      @loadPage()


  load: (url, opts) ->
    if typeof url == 'string'
      url = simple.url url

    return if simple.url().toString() == url.toString()

    opts = $.extend
      nocache: false
    , opts

    if @request
      @request.abort()
      @request = null

    @unload()
    @url = url

    page = @getCache()
    if page and !opts.nocache
      @el.html page.html
    else
      @el.addClass 'pjax-loading'
      page =
        url: url.toString()
        name: @_i18n('loading')
        html: ''

    document.title = page.name
    @trigger 'pushstate.pjax', [page]
    @requestPage page


  requestPage: (page) ->
    @request = $.ajax
      url: page.url
      type: 'get'
      headers:
        "X-PJAX": "true"
      data:
        pjax: 1
      dataType: 'html'
      complete: =>
        @request = null
      error: (xhr) =>
        @trigger 'pjaxerror', [xhr]

        page.html = xhr.responseText
        @loadPage page
        @clearCache()
      success: (result) =>
        page.html = $.trim result
        page.name = ''
        @loadPage page

  loadPage: (page) ->
    if page
      page.url = @url.toString() unless page.url

      try
        $page = $(page.html)
      catch error
        $page = ''

      @el.empty().append $page
      @el.removeClass 'pjax-loading'

      page.name = $page.data 'page-name' unless page.name
      document.title = page.name
    else
      page =
        url: simple.url().toString()
        name: document.title
        html: @el.html()
      $page = @el.children().first()

    @url = simple.url page.url
    @setCache page
    @trigger 'replacestate.pjax', [page]

    pageId = $page.attr 'id'
    @trigger 'pjaxload', [$page, page]
    $(document).trigger 'pjaxload#' + pageId, [$page, page] if pageId

  unload: ->
    page = @getCache() if @url
    if @triggerHandler('pjaxunload', [page]) == false
      return

    if page
      @setCache page
      @trigger 'replacestate.pjax', [page]

    @url = ''
    @el.empty()

  setCache: (page) ->
    unless page
      page = 
        url: @url.toString()
        name: document.title
        html: @el.html()

    Pjax.pageCache[@url.toString()] = page
    page

  getCache: ->
    Pjax.pageCache[@url.toString()]

  clearCache: () ->
    Pjax.pageCache[@url.toString()] = undefined

  @i18n:
    'zh-CN':
      loading: '正在加载'



window.simple ||= {}

simple.pjax = (opts) ->
  new Pjax(opts)
