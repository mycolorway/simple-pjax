module.exports = (grunt) ->

  grunt.initConfig

    pkg: grunt.file.readJSON 'package.json'

    coffee:
      pjax:
        options:
          bare: true
        files:
          'lib/pjax.js': 'src/pjax.coffee'
      demo:
        files:
          'demo/server.js': 'demo/server.coffee'
          'demo/scripts/demo.js': 'demo/scripts/demo.coffee'

    umd:
      all:
        src: 'lib/pjax.js'
        template: 'umd.hbs'
        amdModuleId: 'simple-pjax'
        objectToExport: 'pjax'
        globalAlias: 'pjax'
        deps:
          'default': ['$', 'SimpleModule', 'simpleUrl']
          amd: ['jquery', 'simple-module', 'simple-url']
          cjs: ['jquery', 'simple-module', 'simple-url']
          global:
            items: ['jQuery', 'SimpleModule', 'simple.url']
            prefix: ''

    watch:
      scripts:
        files: ['src/*.coffee', 'demo/**/*.coffee']
        tasks: ['coffee', 'umd']

    express:
      server:
        options:
          server: 'demo/server.js'
          bases: 'demo'


  grunt.loadNpmTasks 'grunt-contrib-sass'
  grunt.loadNpmTasks 'grunt-contrib-coffee'
  grunt.loadNpmTasks 'grunt-contrib-watch'
  grunt.loadNpmTasks 'grunt-umd'
  grunt.loadNpmTasks 'grunt-express'

  grunt.registerTask 'default', ['coffee', 'umd', 'express', 'watch']

