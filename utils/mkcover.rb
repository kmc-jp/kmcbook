#!/usr/bin/ruby1.9.1

require 'optparse'

require 'rubygems'
require 'RMagick'
require 'pango'
require 'typographic-unit'

Unit = TypographicUnit::Unit
class Unit
  def self.parse s
    if /^([+-]?[0-9]*(?:\.[0-9]*)?)\s*([a-z_]+)$/i =~ s
      TypographicUnit::Table[$2.to_sym].new($1.to_f) rescue nil
    else
      nil
    end
  end
  
  def to_dots dpi
    ((self >> :in).to_float * dpi).to_i
  end
end

OptionParser.accept(Unit) do |s|
  Unit.parse(s) or raise OptionParser::InvalidArgument, s
end

Papers = {
  a4: [210.mm, 297.mm],
  jisb5: [182.mm, 257.mm],
}

Opt = Struct.new(:front, :back, :title, :author,
                 :width, :height, :thickness, :tombo,
                 :color, :font, :language,
                 :dpi, :indent, :guide,
                 :margin, :clipping, :padding,
                 :output, :format) do
  
  def initialize mappings={}
    Defaults.merge(mappings).each {|attr, v| public_send("#{attr}=", v) }
  end
  
  private
  Defaults = {
    tombo: true,
    font: 'Sans Bold 16',
    language: 'ja-jp',
    thickness: 8.mm,
    width: 182.mm,
    height: 257.mm,
    dpi: 300,
    margin: 1.in,
    padding: 5.mm,
    clipping: 3.mm,
    indent: 3.mm,
    output: '-'
  }
end

begin
  opt = Opt.new
  
  OptionParser.new do |o|
    o.on('-f', '--front FILE', 'Image file for the front cover', &opt.method(:front=))
    o.on('-b', '--back FILE', 'Image file for the back cover', &opt.method(:back=))
    o.on('-t', '--title TITLE', 'Title of the book printed on the spine', &opt.method(:title=))
    o.on('-a', '--author AUTHOR', 'Author of the book printed on the spine', &opt.method(:author=))
    o.on('-d', '--thickness THICKNESS', Unit, 'Thikness of the book', &opt.method(:thickness=))
    o.on('-p', '--paper PAPER', Papers, 'Paper size by name (default: jisb5)') {|v| opt.width, opt.height = v }
    o.on('--width WIDTH', Unit, 'Width of the paper', &opt.method(:width=))
    o.on('--height HEIGHT', Unit, 'Height of the paper', &opt.method(:height=))
    o.on('--tombo', '--no-tombo', 'Print tombo', &opt.method(:tombo=))
    o.on('--color', '--no-color', 'Color image', &opt.method(:color=))
    o.on('--font FONT', 'Font used for spine printing', &opt.method(:font=))
    o.on('--language LANGTAG', 'Language', &opt.method(:language=))
    o.on('--indent INDENT', 'Indent', Unit, &opt.method(:indent=))
    o.on('--dpi DPI', 'Resolution for the output image', Integer, &opt.method(:dpi=))
    o.on('--margin MARGIN', Unit, 'Margin', &opt.method(:margin=))
    o.on('--clipping CLIPPING', Unit, 'Clipping width arround cover images', &opt.method(:clipping=))
    o.on('--padding PADDING', 'Padding width', &opt.method(:padding=))
    o.on('--guide', 'Show guide lines (implies --color)', &opt.method(:guide=))
    o.on('-o', '--output FILE', 'Output file', &opt.method(:output=))
    o.on('--format FORMAT', 'Output format', &opt.method(:format=))
  end.parse!
  
  opt.color = opt.guide if opt.color.nil?
  
  dpi = opt.dpi
  width = (opt.width + opt.clipping + opt.margin) * 2 + opt.thickness
  height = opt.height + (opt.clipping + opt.margin) * 2
  cwidth = opt.width + opt.clipping * 2
  cheight = opt.height + opt.clipping * 2
  dwidth = opt.width + opt.clipping

  clen = opt.clipping.to_dots(dpi)
  tlen = 10.mm.to_dots(dpi)
  elen = 2.mm.to_dots(dpi)
  mlen = opt.margin.to_dots(dpi)
  plen = opt.padding.to_dots(dpi)
  hlen = height.to_dots(dpi)
  wlen = width.to_dots(dpi)
  pwlen = ((opt.width + opt.clipping) * 2 + opt.thickness).to_dots(dpi)
  phlen = (opt.height + opt.clipping * 2).to_dots(dpi)
  olen = (opt.margin + opt.clipping + opt.width).to_dots(dpi)
  omlen = (opt.clipping + opt.width).to_dots(dpi)
  onlen = (opt.clipping + opt.width + opt.thickness).to_dots(dpi)
  
  include Cairo
  include Magick
  
  img = Image.new(wlen, hlen) {
    self.colorspace = opt.color ? RGBColorspace : GRAYColorspace
    self.image_type = opt.color ? TrueColorType : GrayscaleType
    self.depth = 8
    self.units = PixelsPerInchResolution
    self.density = Geometry.new(dpi)
  }
  
  if opt.front
    cover = Image.read(opt.front) {
      self.units = PixelsPerInchResolution
      self.density = Geometry.new(dpi)
    }.first
    cover.image_type = GrayscaleType unless opt.color
    cover.resize_to_fit!(cwidth.to_dots(dpi), cheight.to_dots(dpi))
    cover.crop!(WestGravity, cover.columns - dwidth.to_dots(dpi), 0, dwidth.to_dots(dpi), cheight.to_dots(dpi))
    offsetx = opt.margin + opt.clipping + opt.thickness + opt.width
    offsety = opt.margin
    img.composite!(cover, offsetx.to_dots(dpi), offsety.to_dots(dpi), OverCompositeOp)
  end
  
  if opt.back
    cover = Image.read(opt.back) {
      self.units = PixelsPerInchResolution
      self.density = Geometry.new(dpi)
    }.first
    cover.image_type = GrayscaleType unless opt.color
    cover.resize_to_fit!(cwidth.to_dots(dpi), cheight.to_dots(dpi))
    cover.crop!(WestGravity, 0, 0, dwidth.to_dots(dpi), cheight.to_dots(dpi))
    offsetx = opt.margin
    offsety = opt.margin
    img.composite!(cover, offsetx.to_dots(dpi), offsety.to_dots(dpi), OverCompositeOp)
  end

  unless opt.thickness.to_dots(dpi).zero?
    surface = ImageSurface.new(opt.thickness.to_dots(dpi), (opt.height - opt.padding * 2).to_dots(dpi))
    ctx = Context.new surface
    
    layout = ctx.create_pango_layout
    layout.context.resolution = dpi
    
    font = Pango::FontDescription.new opt.font
    metrics = layout.context.get_metrics(font, Pango::Language.new(opt.language))
    fontheight = (metrics.ascent) / Pango::SCALE
    layout.font_description = font
    
    ctx.move_to((surface.width + fontheight) / 2, 0)
    ctx.rotate(Math::PI / 2)
    
    layout.context.language = Pango::Language.new(opt.language)
    layout.context.base_gravity = :east
    layout.width = surface.height * Pango::SCALE
    layout.indent = opt.indent.to_dots(dpi) * Pango::SCALE

    if opt.title
      layout.text = opt.title
      layout.alignment = :left
      ctx.show_pango_layout(layout)
    end
    if opt.author
      layout.text = opt.author
      layout.alignment = :right
      ctx.show_pango_layout(layout)
    end

    offsetx = opt.margin + opt.clipping + opt.width
    offsety = opt.margin + opt.clipping + opt.padding
    spine = Image.new(surface.width, surface.height).import_pixels(0,0, surface.width, surface.height, 'BGRA', surface.data)
    img.composite!(spine, offsetx.to_dots(dpi), offsety.to_dots(dpi), OverCompositeOp)
  end

  if opt.guide
    gc = Draw.new
    gc.translate(mlen, mlen)
    gc.stroke_opacity(0)
    
    gc.fill('red')
    gc.fill_opacity(0.5)
    gc.rectangle(0, 0, clen, phlen - clen - 1)
    gc.rectangle(0, phlen, pwlen - clen - 1, phlen - clen)
    gc.rectangle(pwlen, phlen, pwlen - clen, clen + 1)
    gc.rectangle(pwlen, 0, clen + 1, clen)

    gc.fill('yellow')
    gc.fill_opacity(0.5)
    gc.rectangle(clen, clen, clen + plen, phlen - clen - plen - 1)
    gc.rectangle(clen, phlen - clen, pwlen - clen - plen - 1, phlen - clen - plen)
    gc.rectangle(pwlen - clen, phlen - clen, pwlen - clen - plen, clen + plen + 1)
    gc.rectangle(pwlen - clen, clen, clen + plen + 1, clen + plen)

    gc.fill('blue')
    gc.fill_opacity(0.5)
    gc.rectangle(omlen, 0, onlen, phlen)
    gc.draw(img)
  end
  
  if opt.tombo
    [Draw.new.translate(mlen, mlen),
     Draw.new.translate(mlen, hlen - mlen).rotate(270),
     Draw.new.translate(wlen - mlen, hlen - mlen).rotate(180),
     Draw.new.translate(wlen - mlen, mlen).rotate(90)].each do |gc|
      gc.stroke('black')
      gc.fill_opacity(0)
      gc.polyline(-tlen, 0, clen, 0, clen, -tlen)
      gc.polyline(0, -tlen, 0, clen, -tlen, clen)
      gc.draw(img)
    end

    [Draw.new.translate(wlen / 2, mlen),
     Draw.new.translate(wlen / 2, hlen - mlen).rotate(180),
     Draw.new.translate(mlen, hlen / 2).rotate(270),
     Draw.new.translate(wlen - mlen, hlen / 2).rotate(90)].each do |gc|
      gc.stroke('black')
      gc.fill_opacity(0)
      gc.line(0, 0, 0, -tlen)
      gc.line(-tlen, -elen, tlen, -elen)
      gc.draw(img)
    end

    [Draw.new.translate(olen, mlen),
     Draw.new.translate(wlen - olen, mlen),
     Draw.new.translate(olen, hlen - mlen).rotate(180),
     Draw.new.translate(wlen - olen, hlen - mlen).rotate(180)].each do |gc|
      gc.stroke('black')
      gc.fill_opacity(0)
      gc.line(0, 0, 0, -tlen)
      gc.draw(img)
    end
  end

  img.alpha(DeactivateAlphaChannel)
  img.format = opt.format if opt.format

  output = opt.output
  if !output or output == '-'
    img.format ||= 'PNG'
    output = $stdout
  end
  img.write(output) {
    self.units = PixelsPerInchResolution
    self.density = Geometry.new(dpi)
  }
end
