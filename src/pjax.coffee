
class Pjax extends Widget

  opts:
    el: null
    autoload: true
    history: true
    slowTime: 800
    title: '{{ name }}'

  supportHistory: !!(window.history && history.pushState)

  @pageCache: {}

  _init: ->
    return unless @supportHistory

    @el = if @opts.el then $(@opts.el) else $('body')
    @el.addClass 'simple-pjax'

    @el.on 'click', 'a[data-pjax]', (e) =>
      e.preventDefault()
      $link = $(e.currentTarget)
      url = simple.url $link.attr 'href'

      if url
        @load url, 
          nocache: $link.is '[data-pjax-nocache]'
          norefresh: $link.is '[data-pjax-norefresh]'

    @on 'pjaxunload', (e, $page, page) =>
      page.params = {} unless page.params
      $.extend page.params,
        scrollPosition:
          top: $(document).scrollTop()
          left: $(document).scrollLeft()

    @on 'pjaxload', (e, $page, page) =>
      return unless page.url
      url = simple.url page.url
      return unless url.hash

      promises = []
      $page.find('img').each (i, img) =>
        return if img.complete
        $img = $(img)
        dfd = $.Deferred()
        $img.data('dfd', dfd).one 'load', () =>
          dfd = $img.data 'dfd'
          if dfd
            dfd.resolve()
            $img.removeData 'dfd'
        promises.push dfd.promise()

      $.when.apply(@, promises).done () ->
        $page[0].offsetHeight # force relow
        setTimeout ->
          $target = $('#' + url.hash)
          targetOffset = $target.offset()
          $(document).scrollTop(targetOffset.top - 30)
            .scrollLeft(targetOffset.left - 30)
        , 0


    if @opts.history
      $(window).off('popstate.pjax').on 'popstate.pjax', (e) =>
        state = e.originalEvent.state
        return unless state

        if @request
          @request.abort()
          @request = null

        @el.html state.html
        @pageTitle state.name
        #@requestPage state
        @loadPage()

    if @opts.autoload
      if history.state
        @el.html history.state.html
        @pageTitle history.state.name
      @loadPage()

  pageTitle: (title) ->
    if title
      title = @opts.title.replace '{{ name }}', title
      params =
        pjax: @,
        title: title
      $(document).triggerHandler 'setpagetitle.pjax', [params]
      title = params.title
      document.title = title unless document.title == title
    else
      title = document.title
      params =
        pjax: @,
        title: title
      $(document).trigger 'getpagetitle.pjax', [params]

      re = new RegExp @opts.title.replace('{{ name }}', '(\S+)'), 'g'
      match = re.exec params.title
      title = match[1]

    title

  load: (url, opts) ->
    if typeof url == 'string'
      url = simple.url url

    return if @url and @url.toString('relative') == url.toString('relative')

    opts = $.extend
      nocache: false
    , opts

    if @request
      @request.abort()
      @request = null

    if @url and @unload() == false
      return false
    @url = url

    page = @getCache()
    if page and !opts.nocache
      @el.html page.html
    else
      @el.addClass 'pjax-loading'
      @slowTimer = setTimeout =>
        @el.addClass 'pjax-loading-slow'
        @slowTimer = null
      , @opts.slowTime
      page =
        url: url.toString('relative')
        name: @_i18n('loading')
        html: ''

    state = $.extend {}, page
    @trigger 'pushstate', [state]
    title = @pageTitle state.name
    history.pushState state, title, state.url

    @el.height ''
    @trigger 'pjaxbeforeload', [page]

    if opts.scrollPosition and state.params?.scrollPosition
      $(document).scrollTop(state.params.scrollPosition.top)
        .scrollLeft(state.params.scrollPosition.left)
    else
      $(document).scrollTop(0)
        .scrollLeft(0)

    if opts.norefresh and page
      $page = @el.children().first()
      pageId = $page.attr 'id'
      @trigger 'pjaxload', [$page, page]
      $(document).trigger 'pjaxload#' + pageId, [$page, page] if pageId
    else
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
        Pjax.clearCache page.url
      success: (result) =>
        page.html = $.trim result
        page.name = ''
        @loadPage page

  loadPage: (page) ->
    if page
      page.url = @url.toString('relative') unless page.url

      try
        $page = $(page.html)
      catch error
        $page = ''

      clearTimeout @slowTimer if @slowTimer
      @el.empty().append $page
      @el.removeClass 'pjax-loading'
      @el.removeClass 'pjax-loading-slow'

      page.name = $page.data 'page-name' unless page.name
    else
      $page = @el.children().first()
      page =
        url: simple.url().toString('relative')
        name: $page.data('page-name') || @pageTitle()
        html: @el.html()

    @url = simple.url page.url
    @setCache page

    state = $.extend {}, page
    @trigger 'replacestate', [state]
    title = @pageTitle state.name
    history.replaceState state, title, state.url

    @el.height ''

    pageId = $page.attr 'id'
    @trigger 'pjaxload', [$page, page]
    $(document).trigger 'pjaxload#' + pageId, [$page, page] if pageId

  unload: ->
    page = @setCache() if @url
    if @triggerHandler('pjaxunload', [@el.children().first(), page]) == false
      return false

    if page
      state = $.extend {}, page
      @trigger 'replacestate', [state]
      title = @pageTitle state.name
      history.replaceState state, title, state.url

    @url = null

    # prevese height before unload for saving scroll position
    @el.height @el.height()

    @el.empty()
    page

  setCache: (page) ->
    unless page
      $page = @el.children().first()
      page = 
        url: @url.toString('relative')
        name: $page.data('page-name') || @pageTitle()
        html: @el.html()

    Pjax.pageCache[page.url] = page
    page

  getCache: ->
    Pjax.pageCache[@url.toString('relative')]

  @clearCache: (url) ->
    if url
      if typeof url == 'string'
        url = simple.url(url).toString('relative')
      Pjax.pageCache[url] = undefined
    else
      Pjax.pageCache = {}

  @i18n:
    'zh-CN':
      loading: '正在加载'



window.simple ||= {}

simple.pjax = (opts) ->
  new Pjax(opts)

simple.pjax.clearCache = Pjax.clearCache

