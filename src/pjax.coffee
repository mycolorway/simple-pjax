
class Pjax extends SimpleModule

  opts:
    el: null
    autoload: true
    history: true
    slowTime: 800
    title: '{{ name }}'
    linkAttribute: 'data-pjax'

  supportHistory: !!(window.history && history.pushState)

  @pageCache: {}

  _init: ->
    return unless @supportHistory

    @el = if @opts.el then $(@opts.el) else $('body')
    @el.addClass 'simple-pjax'

    $(document).on 'click', "a[#{@opts.linkAttribute}]", (e) =>
      e.preventDefault()
      $link = $(e.currentTarget)
      url = simple.url $link.attr 'href'

      if url
        @load url,
          nocache: $link.is "[#{@opts.linkAttribute}-nocache]"
          norefresh: $link.is "[#{@opts.linkAttribute}-norefresh]"

    @on 'pjaxunload', (e, $page, page) =>
      page = {} unless page
      page.params = {} unless page.params

      selector = $page.data('scroll-container-selector')
      $scrollContainer = if selector then $(selector) else $(document)
      $scrollContainer = $(document) unless $scrollContainer.length

      $.extend page.params,
        scrollPosition:
          top: $scrollContainer.scrollTop()
          left: $scrollContainer.scrollLeft()

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
          try
            $target = $("##{url.hash}")
            return unless $target.length > 0
            targetOffset = $target.offset()
            $(document).scrollTop(targetOffset.top - 30)
              .scrollLeft(targetOffset.left - 30)
          catch error
        , 0


    if @opts.history
      $(window).off('popstate.pjax').on 'popstate.pjax', (e) =>
        state = e.originalEvent.state
        return unless state

        if @triggerHandler('pajxunload', [@el.children().first(), @getCache()]) == false
          return

        if @request
          @request.abort()
          @request = null

        page = @getCache state.url
        return unless page

        @el[0].innerHTML = page.html
        @el[0].offsetHeight
        @pageTitle state.name
        #@requestPage state
        @loadPage()

    if @opts.autoload
      #if history.state
        #@el.html history.state.html
        #@pageTitle history.state.name
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

      re = new RegExp @opts.title.replace('{{ name }}', '(\\S+)'), 'g'
      match = re.exec params.title
      title = match[1] if match

    title

  load: (url, opts) ->
    if typeof url == 'string'
      url = simple.url url

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

    scrollPosition =
      top: 0
      left: 0

    if page and !page.nocache and !opts.nocache
      if opts.scrollPosition and page.params?.scrollPosition
        scrollPosition.top = page.params.scrollPosition.top
        scrollPosition.left = page.params.scrollPosition.left

      @el[0].innerHTML = page.html
      @restoreScrollPosition @el.children().first(), scrollPosition
      @el.offsetHeight # force reflow
    else
      @el.addClass 'pjax-loading'
      @slowTimer = setTimeout =>
        @el.addClass 'pjax-loading-slow'
        @slowTimer = null
      , @opts.slowTime
      page =
        url: url.toString('relative')
        name: document.title
        html: ''

    state = $.extend {}, page,
      html: ''
    @trigger 'pushstate', [state]
    history.pushState state, state.name, state.url
    @pageTitle @_t('loading')

    @el.height ''
    @trigger 'pjaxbeforeload', [page]

    if opts.norefresh and page
      $page = @el.children().first()
      pageId = $page.attr 'id'
      $(document).trigger 'pjaxload#' + pageId, [$page, page] if pageId
      @trigger 'pjaxload', [$page, page]
    else
      @requestPage page, scrollPosition

  requestPage: (page, scrollPosition) ->
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
      error: (xhr, status) =>
        return if status is 'abort'
        @trigger 'pjaxerror', [xhr]

        page.html = xhr.responseText
        @loadPage page
        Pjax.clearCache page.url
      success: (result, status, xhr) =>
        page.html = $.trim result
        page.name = ''

        if pageUrl = xhr.getResponseHeader 'X-PJAX-URL'
          originUrl = simple.url page.url
          pageUrl = simple.url(pageUrl)
          pageUrl.hash = originUrl.hash unless pageUrl.hash
          page.url = pageUrl.toString('relative')

        @loadPage page, xhr, scrollPosition

  loadPage: (page, xhr, scrollPosition) ->
    if page
      page.url = @url.toString('relative') unless page.url

      try
        $page = $(page.html)
      catch error
        $page = ''

      clearTimeout @slowTimer if @slowTimer


      @el.empty().append $page
      @restoreScrollPosition $page, scrollPosition
      @el.offsetHeight # force reflow
      @el.removeClass 'pjax-loading'
      @el.removeClass 'pjax-loading-slow'

      page.name = $page.data('page-name') if $page && !page.name
    else
      $page = @el.children().first()
      page =
        url: simple.url().toString('relative')
        name: $page.data('page-name') || @pageTitle()
        html: @el.html()

    @url = simple.url page.url
    @setCache page

    state = $.extend {}, page,
      html: ''
    @trigger 'replacestate', [state]
    title = @pageTitle state.name
    history.replaceState state, title, state.url

    @el.height ''

    pageId = $page.attr 'id'
    $(document).trigger 'pjaxload#' + pageId, [$page, page] if pageId
    @trigger 'pjaxload', [$page, page, xhr]

  unload: ->
    page = @setCache() if @url
    if @triggerHandler('pjaxunload', [@el.children().first(), page]) == false
      return false

    if page
      # set cache again for posible dom change in unload event
      page.html = @el.html()
      @setCache page

      state = $.extend {}, page,
        html: ''
      @trigger 'replacestate', [state]
      title = @pageTitle state.name
      history.replaceState state, title, state.url

    @url = null

    # prevese height before unload for saving scroll position
    @el.height @el.height()

    @el.empty()
    page

  setCache: (page) ->
    return if @el.hasClass 'pjax-loading'

    unless page
      $page = @el.children().first()
      page =
        url: @url.toString('relative')
        name: $page.data('page-name') || @pageTitle()
        html: @el.html()
        nocache: $page.is "[#{@opts.linkAttribute}-nocache]"

    Pjax.pageCache[page.url] = page
    page

  getCache: (url = @url?.toString('relative')) ->
    if url
      Pjax.pageCache[url]
    else
      null

  restoreScrollPosition: ($page, scrollPosition) ->
    try
      $scrollContainer = $($page.data('scroll-container-selector'))
      $scrollContainer = $(document) unless $scrollContainer.length
    catch error
      $scrollContainer = $(document)

    unless scrollPosition
      scrollPosition =
        top: 0
        left: 0

    $scrollContainer.scrollTop(scrollPosition.top)
      .scrollLeft(scrollPosition.left)

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



pjax = (opts) ->
  new Pjax(opts)

pjax.clearCache = Pjax.clearCache

