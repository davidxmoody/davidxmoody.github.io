moment = require('moment')
Metalsmith = require('metalsmith')
templates = require('metalsmith-templates')
permalinks = require('metalsmith-permalinks')
collections = require('metalsmith-collections')
each = require('metalsmith-each')
dateInFilename = require('metalsmith-date-in-filename')
pagination = require('metalsmith-pagination')
serve = require('metalsmith-serve')
sass = require('metalsmith-sass')
ignore = require('metalsmith-ignore')
beautify = require('metalsmith-beautify')
feed = require('metalsmith-feed')
fingerprint = require('metalsmith-fingerprint')
drafts = require('metalsmith-drafts')
pdf = require('metalsmith-pdf')

markdown = require('./markdown')
excerpts = require('./excerpts')

extname = require('path').extname

EXCERPT_SEPARATOR = '\n\n\n'

METADATA =
  title: 'David Moody\'s Blog'
  description: 'A blog about programming'
  url: 'http://davidxmoody.com'
  feedPath: 'feed.xml'
  gitHubURL: 'https://github.com/davidxmoody'
  email: 'david@davidxmoody.com'

isHTML = (file) ->
  /\.html/.test extname(file)

Metalsmith(__dirname + '/..')

  # CONFIG ####################################################################

  .clean true
  .metadata METADATA

  # POSTS #####################################################################
  
  #TODO do drafts better
  .use drafts()
  
  #TODO choose a better method of post naming
  .use dateInFilename()
  
  .use each (file) ->
    if file.date
      file.formattedDate = moment(file.date).format('ll')
    return

  .use collections posts: {
    pattern: 'posts/*.md'
    sortBy: 'date'
    reverse: true
  }
  
  # Convert space separated string of tags into a list
  .use each (file) ->
    if file.tags and typeof file.tags == 'string'
      file.tags = file.tags.split(' ')
    return

  # Replace custom EXCERPT_SEPARATOR with <!--more--> tag
  .use (files, metalsmith) ->
    metalsmith.metadata().posts.forEach (file) ->
      file.contents = new Buffer(file.contents.toString().replace(EXCERPT_SEPARATOR, '\n\n<!--more-->\n\n'))
      return
    return

  .use markdown()
  
  .use permalinks pattern: ':title/'

  # HOME PAGE PAGINATION ######################################################
  
  .use pagination 'collections.posts': {
    perPage: 6
    template: 'list.html'
    first: 'index.html'
    path: 'page:num/index.html'
    pageMetadata: {}
  }
  
  # Don't duplicate the first page
  .use ignore ['page1/index.html']
  
  # Clean up paths to provide clean URLs
  .use each (file, filename) ->
    file.path = filename.replace(/index.html$/, '')
    return

  # EXCERPTS ##################################################################

  .use excerpts()
  
  .use each (file) ->
    pagin = file.pagination
    if pagin
      links = []

      links.push if pagin.previous
        '<a href="/' + pagin.previous.path + '">&laquo;</a>'
      else
        '<span>&laquo;</span>'

      for page in pagin.pages
        links.push if file == page
          '<span>' + page.pagination.num + '</span>'
        else
          '<a href="/' + page.path + '">' + page.pagination.num + '</a>'

      links.push if pagin.next
        '<a href="/' + pagin.next.path + '">&raquo;</a>'
      else
        '<span>&raquo;</span>'

      pagin.linksHTML = '<p class="pagination">' + links.join('|') + '</p>'
    return

  # CSS AND FINGERPRINTING ####################################################

  .use sass()
  
  .use fingerprint pattern: 'css/main.css'
  
  .use ignore [
    'css/_*.sass'
    'css/main.css'
  ]

  # TEMPLATES #################################################################

  # Use templates once then once again to wrap every HTML file in default.html

  .use (files, metalsmith) ->
    #TODO find a better way to iterate over all posts in CoffeeScript
    metalsmith.metadata().posts.forEach (file) ->
      file.template = 'post.html'
      return
    return

  .use templates 'handlebars'
  
  .use each (file, filename) ->
    if isHTML(filename)
      file.template = 'default.html'
    return

  .use templates 'handlebars'

  # BEAUTIFY ##################################################################
  
  #TODO consider removing or changing
  .use beautify {
    wrap_line_length: 79
    indent_size: 2
    indent_char: ' '
  }

  # RSS FEED ##################################################################
  
  .use feed {
    collection: 'posts'
    limit: 20
    destination: METADATA.feedPath
    title: METADATA.title
    site_url: METADATA.url
    description: METADATA.description
  }

  .use (files) ->
    # Make all relative links and images into absolute links and images
    data = files[METADATA.feedPath]
    replaced = data.contents.toString().replace(/(src|href)="\//g, '$1="' + METADATA.url)
    data.contents = new Buffer(replaced)

  # CV PDF ####################################################################

  .use pdf {
    pattern: 'cv/index.html'
    printMediaType: true
    marginTop: '1.5cm'
    marginBottom: '1.5cm'
  }

  # Rename CV to something more meaningful
  .use (files) ->
    oldPath = 'cv/index.pdf'
    newPath = 'cv/david-moody-cv-web-developer.pdf'

    files[newPath] = files[oldPath]
    delete files[oldPath]

  # SERVE AND BUILD ###########################################################

  .use serve()
  .build (err) ->
    throw err if err