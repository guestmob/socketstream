# Asset Packer
# ------------
# Pre-concatenates/compiles/minifies files in advance to be served by the node static server

fs = require('fs')
util = require('util')
coffee = require('coffee-script')

EventEmitter = require('events').EventEmitter
emitter = new EventEmitter

utils = require('./utils.coffee')
file_utils = require('../../utils/file')

# Define where the SocketStream client files live
system_path = __dirname + '/../client'
bin_path    = __dirname + '/../../../bin'

cdn_push   = "#{bin_path}" + '/rackspace_upload.sh'
cdn_target = 'cdn_images'


exports.init = (@assets) ->
  @

exports.pack =
  
  all: ->
    try
      util.log "Pre-packing all client assets..."
      @libs()
      @js.app()
      @css.app()
      @html.app()
    catch e
      # Removes the .socketstream_state file to force asset files to rebuild next time instead of leaving empty/broken files
      SS.internal.state.reset()
      SS.log.error.exception e
      throw 'Error: Unable to pack client assets. Files will be re-generated next time'
  
  libs: ->
    @js.lib()
    @css.lib()

  debuglibs: ->
    @js.debuglib()
    @css.debuglib()
  
  html:
    
    app: (cb = ->) ->        
      exports.assets.compile.jade 'app.jade', (result) ->
        fs.writeFileSync './public/index.html', result.output
        util.log('Compiled app.jade to index.html')
        cb()
  
  js:
    
    app: ->
      output = []

      path = "./lib/client"
      if files = file_utils.readDirSync(path).files
        files.forEach (file) ->
          if file.split('.')[1] == 'coffee'
            util.log (' Warning! Coffee script in LIB:' + file)
            exports.assets.compile.coffee file, (result) ->
              yui = utils.yuiJS(file, result, output)
              output.push (yui)
          else
            util.log('  Adding and YUI compressing ' + file)
            js = fs.readFileSync "#{file}", 'utf8'
            js = utils.yuiJS("#{file}", js)
            output.push(js)
      final_output = output.join("\n")
      final_output += "\n"
      util.log("  Appending #{system_path}/cached/lib.min.js")
      final_output += fs.readFileSync("#{system_path}/cached/lib.min.js", 'utf8')
      final_output += "\n"
  
      output = []

      exports.assets.client_dirs.map (dir) ->
        path = "./app/#{dir}"
        if files = file_utils.readDirSync(path).files
          files = utils.ensureCorrectOrder(files)
          files.forEach (file) ->
            if file.split('.')[1] == 'coffee'
              util.log('  Compiling, adding and YUI compressing ' + file)
              exports.assets.compile.coffee file, (result) ->
                yui = utils.yuiJS(file, result.output)
                output.push (yui)
            else
              util.log('  Adding and YUI compressing ' + file)
              js = fs.readFileSync "#{SS.root}/#{file}", 'utf8'
              js = utils.yuiJS("#{file}", js) 
              output.push(js)

      if output.length
        final_output += output.join("\n")
        #final_output = utils.minifyJS('application code', final_output)

      deleteFilesInPublicDir(/^app.*js$/)
      exports.assets.files.js.app = "app_#{Date.now()}.js"
      fs.writeFileSync("#{exports.assets.public_path}/#{exports.assets.files.js.app}", final_output)
      utils.execSync("cd #{exports.assets.public_path}; #{cdn_push} #{cdn_target} #{exports.assets.files.js.app}")
      
    lib: ->
      deleteFilesInPublicDir(/^lib.*js$/)
      exports.assets.files.js.lib = "lib_#{Date.now()}.js"
      output = ''
      #output = utils.concatFiles('./lib/client')
      #util.log("  Appending SocketStream client files...")
      #output += fs.readFileSync("#{system_path}/cached/lib.min.js", 'utf8')
      fs.writeFileSync("#{exports.assets.public_path}/#{exports.assets.files.js.lib}", output)
      emitter.emit('regenerate_html')

    debuglib: ->
      deleteFilesInPublicDir(/^lib.*js$/)
      exports.assets.files.js.lib = "lib_#{Date.now()}.js"
      output = utils.concatFiles('./lib/client')
      util.log("  Appending SocketStream LIB client files...")
      output += fs.readFileSync("#{system_path}/cached/lib.min.js", 'utf8')
      fs.writeFileSync("#{exports.assets.public_path}/#{exports.assets.files.js.lib}", output)
      emitter.emit('regenerate_html')
    
    # SocketStream developers only!
    # Should only ever be called when modifying a SocketStream client lib file directly.
    # Will only save correctly if package is linked with 'sudo npm link'
    system: ->
      client_file_path = "#{system_path}/socketstream.coffee"
      output = utils.concatFiles("#{system_path}/js")
      client = fs.readFileSync client_file_path, 'utf8'
      try
        js = coffee.compile(client)
        util.log("  Compiled SocketStream client into JS")
        output += utils.minifyJS('client file', js)
        fs.writeFileSync("#{system_path}/cached/lib.min.js", output)
      catch e
        SS.log.error.exception("Error: Unable to compile or save the SocketStream client file to JS")
        throw new Error(e)
      util.log("SocketStream system client files updated. Recompiling application lib file to include new code...")
      exports.assets.pack.js.lib()
    
  css:
    
    app: ->
      deleteFilesInPublicDir(/^app.*css$/)
      exports.assets.files.css.app = "app_#{Date.now()}.css"
      exports.assets.compile.styl 'app.styl', (result) ->
        fs.writeFileSync("#{exports.assets.public_path}/#{exports.assets.files.css.app}", result.output)
        util.log('Stylus files compiled into CSS')
      
    debuglib: ->
      deleteFilesInPublicDir(/^lib.*css$/)
      output = utils.concatFiles("./lib/css")
      exports.assets.files.css.lib = "lib_#{Date.now()}.css"
      fs.writeFileSync("#{exports.assets.public_path}/#{exports.assets.files.css.lib}", output)
      util.log('CSS libs concatenated')
      utils.yuiCSS("#{exports.assets.public_path}/#{exports.assets.files.css.lib}")
      emitter.emit('regenerate_html')
  
    lib: ->
      @debuglib()
      utils.execSync("cd #{exports.assets.public_path}; #{cdn_push} #{cdn_target} #{exports.assets.files.css.lib}")

      


# PRIVATE

deleteFilesInPublicDir = (rexexp) ->
  fs.readdirSync(exports.assets.public_path).map (file) ->
    fs.unlink("#{exports.assets.public_path}/#{file}") if file.match(rexexp)
