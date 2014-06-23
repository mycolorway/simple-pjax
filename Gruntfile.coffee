module.exports = (grunt) ->

  grunt.initConfig

    pkg: grunt.file.readJSON 'package.json'

    coffee:
      pjax:
        files:
          'lib/pjax.js': 'src/pjax.coffee'
      demo:
        files:
          'demo/server.js': 'demo/server.coffee'
          'demo/scripts/demo.js': 'demo/scripts/demo.coffee'

    watch:
      scripts:
        files: ['src/*.coffee', 'demo/**/*.coffee']
        tasks: ['coffee']

    express:
      server:
        options:
          server: 'demo/server.js'
          bases: 'demo'


  grunt.loadNpmTasks 'grunt-contrib-sass'
  grunt.loadNpmTasks 'grunt-contrib-coffee'
  grunt.loadNpmTasks 'grunt-contrib-watch'
  grunt.loadNpmTasks 'grunt-express'

  grunt.registerTask 'default', ['coffee', 'express', 'watch']

