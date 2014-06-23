
$ ->

  $(document).on 'pjaxload#page-1', ($page, page) ->
    console.log 'page 1 loaded'

  $(document).on 'pjaxload#page-2', ($page, page) ->
    console.log 'page 2 loaded'

  $(document).on 'pjaxload#page-3', ($page, page) ->
    console.log 'page 3 loaded'

  pajx = simple.pjax
    el: '#page-wrapper'
