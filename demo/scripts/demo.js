(function() {
  $(function() {
    var pajx;
    $(document).on('pjaxload#page-1', function($page, page) {
      return console.log('page 1 loaded');
    });
    $(document).on('pjaxload#page-2', function($page, page) {
      return console.log('page 2 loaded');
    });
    $(document).on('pjaxload#page-3', function($page, page) {
      return console.log('page 3 loaded');
    });
    return pajx = simple.pjax({
      el: '#page-wrapper'
    });
  });

}).call(this);
