React = require "react"

module.exports = React.createClass
  displayName: "Article"

  propTypes:
    file: React.PropTypes.object.isRequired
    shortened: React.PropTypes.bool

  render: ->
    content = if @props.shortened
      <div dangerouslySetInnerHTML={__html: @props.file.excerpt} />
    else
      <div dangerouslySetInnerHTML={__html: @props.file.contents.toString()} />

    <article>
      <header>
        <h1>{@props.file.title}</h1>
        <p><em>{@props.file.formattedDate}</em></p>
      </header>

      {content}
    </article>
