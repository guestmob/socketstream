# Assets Util Helpers

fs = require("fs")
util = require("util")
ffi  = require("node-ffi")
coffee = require('coffee-script')
uglifyjs = require('uglify-js')

system_path = __dirname + '/../../../bin'


java = '/usr/bin/env java -jar '
yui  = "#{system_path}" + "/yuicompressor-2.4.7.jar "

exports.fileList = (path, first_file = null) ->
  try
    files = fs.readdirSync(path).filter((file) -> !file.match(/(^_|^\.)/)).sort()
    if first_file and files.include(first_file)
      files = files.delete(first_file)
      files.unshift(first_file) 
    files
  catch e
    throw e unless e.code == 'ENOENT' # dir missing
    []

exports.concatFiles = (path) ->
  files = @fileList path
  files.map (file_name) ->
    util.log "   Concatenating file #{file_name}"
    output = fs.readFileSync("#{path}/#{file_name}", 'utf8')
    if file_name.match(/\.coffee$/i)
      util.log "  Compiling #{file_name} into JS..."
      try
        output = coffee.compile(output) 
      catch e
        util.log "\x1B[1;31mError: Unable to compile CoffeeScript file #{path} to JS\x1B[0m"
        throw new Error(e) 
    output = exports.minifyJS(file_name, output) if file_name.match(/\.(coffee|js)/) and !file_name.match(/\.min/)
    output += ';' if file_name.match(/\.js/) # Ensures the file ends with a semicolon. Many libs don't and would otherwise break when concatenated
    output
  .join("\n")

exports.minifyJS = (file_name, orig_code) ->
  formatKb = (size) -> "#{Math.round(size * 1000) / 1000} KB"
  orig_size = (orig_code.length / 1024)
  jsp = uglifyjs.parser
  pro = uglifyjs.uglify
  ast = jsp.parse(orig_code)
  #ast = pro.ast_mangle(ast)
  ast = pro.ast_squeeze(ast)
  minified = pro.gen_code(ast)
  min_size = (minified.length / 1024)
  util.log("  Minified #{file_name} from #{formatKb(orig_size)} to #{formatKb(min_size)}")
  minified

exports.yuiJS = (file_name, orig_code) ->
  #util.log("  YUI compress #{file_name}")
  jsTmp = file_name + '.js'
  fs.writeFileSync(jsTmp, orig_code)
  @execSync("#{java} #{yui} --charset utf-8 " + jsTmp + ' -o ' + jsTmp)
  yuiCode = fs.readFileSync(jsTmp, 'utf8')
  fs.unlinkSync(jsTmp)
  yuiCode 

exports.yuiCSS = (file_name) ->
  #util.log("  YUI compress #{file_name}")
  @execSync("#{java} #{yui} #{file_name} -o #{file_name}")

# Need to run synchronously to make sure all files are processed
exports.execSync = (cmd) ->
  libc = ffi.Library null, system : ['int32', ['string']]
  run = libc.system
  #util.log(cmd)
  run cmd

  
# When serving client files app.coffee or app.js must always be loaded first, so we're ensuring this here for now.
# This is only temporary as big changes are coming to the way we serve and organise client files
exports.ensureCorrectOrder = (files) ->
  matches = files.filter (path) ->
    file = path.split('/').reverse()[0]
    file.split('.')[0] == 'app'
  first_file = matches[0]
  if files.include(first_file) 
    files = files.delete(first_file)
    files.unshift(first_file)
  files
