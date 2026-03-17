// Simple numbering for non-book documents
#let equation-numbering = "(1)"
#let callout-numbering = "1"
#let subfloat-numbering(n-super, subfloat-idx) = {
  numbering("1a", n-super, subfloat-idx)
}

// Theorem configuration for theorion
// Simple numbering for non-book documents (no heading inheritance)
#let theorem-inherited-levels = 0

// Theorem numbering format (can be overridden by extensions for appendix support)
// This function returns the numbering pattern to use
#let theorem-numbering(loc) = "1.1"

// Default theorem render function
#let theorem-render(prefix: none, title: "", full-title: auto, body) = {
  if full-title != "" and full-title != auto and full-title != none {
    strong[#full-title.]
    h(0.5em)
  }
  body
}
// Some definitions presupposed by pandoc's typst output.
#let content-to-string(content) = {
  if content.has("text") {
    content.text
  } else if content.has("children") {
    content.children.map(content-to-string).join("")
  } else if content.has("body") {
    content-to-string(content.body)
  } else if content == [ ] {
    " "
  }
}

#let horizontalrule = line(start: (25%,0%), end: (75%,0%))

#let endnote(num, contents) = [
  #stack(dir: ltr, spacing: 3pt, super[#num], contents)
]

#show terms.item: it => block(breakable: false)[
  #text(weight: "bold")[#it.term]
  #block(inset: (left: 1.5em, top: -0.4em))[#it.description]
]

// Some quarto-specific definitions.

#show raw.where(block: true): set block(
    fill: luma(230),
    width: 100%,
    inset: 8pt,
    radius: 2pt
  )

#let block_with_new_content(old_block, new_content) = {
  let fields = old_block.fields()
  let _ = fields.remove("body")
  if fields.at("below", default: none) != none {
    // TODO: this is a hack because below is a "synthesized element"
    // according to the experts in the typst discord...
    fields.below = fields.below.abs
  }
  block.with(..fields)(new_content)
}

#let empty(v) = {
  if type(v) == str {
    // two dollar signs here because we're technically inside
    // a Pandoc template :grimace:
    v.matches(regex("^\\s*$")).at(0, default: none) != none
  } else if type(v) == content {
    if v.at("text", default: none) != none {
      return empty(v.text)
    }
    for child in v.at("children", default: ()) {
      if not empty(child) {
        return false
      }
    }
    return true
  }

}

// Subfloats
// This is a technique that we adapted from https://github.com/tingerrr/subpar/
#let quartosubfloatcounter = counter("quartosubfloatcounter")

#let quarto_super(
  kind: str,
  caption: none,
  label: none,
  supplement: str,
  position: none,
  subcapnumbering: "(a)",
  body,
) = {
  context {
    let figcounter = counter(figure.where(kind: kind))
    let n-super = figcounter.get().first() + 1
    set figure.caption(position: position)
    [#figure(
      kind: kind,
      supplement: supplement,
      caption: caption,
      {
        show figure.where(kind: kind): set figure(numbering: _ => {
          let subfloat-idx = quartosubfloatcounter.get().first() + 1
          subfloat-numbering(n-super, subfloat-idx)
        })
        show figure.where(kind: kind): set figure.caption(position: position)

        show figure: it => {
          let num = numbering(subcapnumbering, n-super, quartosubfloatcounter.get().first() + 1)
          show figure.caption: it => block({
            num.slice(2) // I don't understand why the numbering contains output that it really shouldn't, but this fixes it shrug?
            [ ]
            it.body
          })

          quartosubfloatcounter.step()
          it
          counter(figure.where(kind: it.kind)).update(n => n - 1)
        }

        quartosubfloatcounter.update(0)
        body
      }
    )#label]
  }
}

// callout rendering
// this is a figure show rule because callouts are crossreferenceable
#show figure: it => {
  if type(it.kind) != str {
    return it
  }
  let kind_match = it.kind.matches(regex("^quarto-callout-(.*)")).at(0, default: none)
  if kind_match == none {
    return it
  }
  let kind = kind_match.captures.at(0, default: "other")
  kind = upper(kind.first()) + kind.slice(1)
  // now we pull apart the callout and reassemble it with the crossref name and counter

  // when we cleanup pandoc's emitted code to avoid spaces this will have to change
  let old_callout = it.body.children.at(1).body.children.at(1)
  let old_title_block = old_callout.body.children.at(0)
  let children = old_title_block.body.body.children
  let old_title = if children.len() == 1 {
    children.at(0)  // no icon: title at index 0
  } else {
    children.at(1)  // with icon: title at index 1
  }

  // TODO use custom separator if available
  // Use the figure's counter display which handles chapter-based numbering
  // (when numbering is a function that includes the heading counter)
  let callout_num = it.counter.display(it.numbering)
  let new_title = if empty(old_title) {
    [#kind #callout_num]
  } else {
    [#kind #callout_num: #old_title]
  }

  let new_title_block = block_with_new_content(
    old_title_block,
    block_with_new_content(
      old_title_block.body,
      if children.len() == 1 {
        new_title  // no icon: just the title
      } else {
        children.at(0) + new_title  // with icon: preserve icon block + new title
      }))

  align(left, block_with_new_content(old_callout,
    block(below: 0pt, new_title_block) +
    old_callout.body.children.at(1)))
}

// 2023-10-09: #fa-icon("fa-info") is not working, so we'll eval "#fa-info()" instead
#let callout(body: [], title: "Callout", background_color: rgb("#dddddd"), icon: none, icon_color: black, body_background_color: white) = {
  block(
    breakable: false, 
    fill: background_color, 
    stroke: (paint: icon_color, thickness: 0.5pt, cap: "round"), 
    width: 100%, 
    radius: 2pt,
    block(
      inset: 1pt,
      width: 100%, 
      below: 0pt, 
      block(
        fill: background_color,
        width: 100%,
        inset: 8pt)[#if icon != none [#text(icon_color, weight: 900)[#icon] ]#title]) +
      if(body != []){
        block(
          inset: 1pt, 
          width: 100%, 
          block(fill: body_background_color, width: 100%, inset: 8pt, body))
      }
    )
}


// syntax highlighting functions from skylighting:
/* Function definitions for syntax highlighting generated by skylighting: */
#let EndLine() = raw("\n")
#let Skylighting(fill: none, number: false, start: 1, sourcelines) = {
   let blocks = []
   let lnum = start - 1
   let bgcolor = rgb("#f1f3f5")
   for ln in sourcelines {
     if number {
       lnum = lnum + 1
       blocks = blocks + box(width: if start + sourcelines.len() > 999 { 30pt } else { 24pt }, text(fill: rgb("#aaaaaa"), [ #lnum ]))
     }
     blocks = blocks + ln + EndLine()
   }
   block(fill: bgcolor, width: 100%, inset: 8pt, radius: 2pt, blocks)
}
#let AlertTok(s) = text(fill: rgb("#ad0000"),raw(s))
#let AnnotationTok(s) = text(fill: rgb("#5e5e5e"),raw(s))
#let AttributeTok(s) = text(fill: rgb("#657422"),raw(s))
#let BaseNTok(s) = text(fill: rgb("#ad0000"),raw(s))
#let BuiltInTok(s) = text(fill: rgb("#003b4f"),raw(s))
#let CharTok(s) = text(fill: rgb("#20794d"),raw(s))
#let CommentTok(s) = text(fill: rgb("#5e5e5e"),raw(s))
#let CommentVarTok(s) = text(style: "italic",fill: rgb("#5e5e5e"),raw(s))
#let ConstantTok(s) = text(fill: rgb("#8f5902"),raw(s))
#let ControlFlowTok(s) = text(weight: "bold",fill: rgb("#003b4f"),raw(s))
#let DataTypeTok(s) = text(fill: rgb("#ad0000"),raw(s))
#let DecValTok(s) = text(fill: rgb("#ad0000"),raw(s))
#let DocumentationTok(s) = text(style: "italic",fill: rgb("#5e5e5e"),raw(s))
#let ErrorTok(s) = text(fill: rgb("#ad0000"),raw(s))
#let ExtensionTok(s) = text(fill: rgb("#003b4f"),raw(s))
#let FloatTok(s) = text(fill: rgb("#ad0000"),raw(s))
#let FunctionTok(s) = text(fill: rgb("#4758ab"),raw(s))
#let ImportTok(s) = text(fill: rgb("#00769e"),raw(s))
#let InformationTok(s) = text(fill: rgb("#5e5e5e"),raw(s))
#let KeywordTok(s) = text(weight: "bold",fill: rgb("#003b4f"),raw(s))
#let NormalTok(s) = text(fill: rgb("#003b4f"),raw(s))
#let OperatorTok(s) = text(fill: rgb("#5e5e5e"),raw(s))
#let OtherTok(s) = text(fill: rgb("#003b4f"),raw(s))
#let PreprocessorTok(s) = text(fill: rgb("#ad0000"),raw(s))
#let RegionMarkerTok(s) = text(fill: rgb("#003b4f"),raw(s))
#let SpecialCharTok(s) = text(fill: rgb("#5e5e5e"),raw(s))
#let SpecialStringTok(s) = text(fill: rgb("#20794d"),raw(s))
#let StringTok(s) = text(fill: rgb("#20794d"),raw(s))
#let VariableTok(s) = text(fill: rgb("#111111"),raw(s))
#let VerbatimStringTok(s) = text(fill: rgb("#20794d"),raw(s))
#let WarningTok(s) = text(style: "italic",fill: rgb("#5e5e5e"),raw(s))


#import "@preview/fontawesome:0.6.0": *

//------------------------------------------------------------------------------
// Style
//------------------------------------------------------------------------------

// const color
#let color-darknight = rgb("#131A28")
#let color-darkgray = rgb("#333333")
#let color-middledarkgray = rgb("#414141")
#let color-gray = rgb("#5d5d5d")
#let color-lightgray = rgb("#999999")

// Default style
#let state-font-header = state("font-header", (:))
#let state-font-text = state("font-text", (:))
#let state-color-accent = state("color-accent", color-darknight)
#let state-color-link = state("color-link", color-darknight)

//------------------------------------------------------------------------------
// Helper functions
//------------------------------------------------------------------------------

// icon string parser

#let parse_icon_string(icon_string) = {
  if icon_string.starts-with("fa ") [
    #let parts = icon_string.split(" ")
    #if parts.len() == 2 {
      fa-icon(parts.at(1), fill: color-darknight)
    } else if parts.len() == 3 and parts.at(1) == "brands" {
      fa-icon(parts.at(2), font: "Font Awesome 6 Brands", fill: color-darknight)
    } else {
      assert(false, "Invalid fontawesome icon string")
    }
  ] else if icon_string.ends-with(".svg") [
    #box(image(icon_string))
  ] else {
    assert(false, "Invalid icon string")
  }
}

// contaxt text parser
#let unescape_text(text) = {
  // This is not a perfect solution
  text.replace("\\", "").replace(".~", ". ")
}

// layout utility
#let __justify_align(left_body, right_body) = {
  block[
    #box(width: 4fr)[#left_body]
    #box(width: 1fr)[
      #align(right)[
        #right_body
      ]
    ]
  ]
}

#let __justify_align_3(left_body, mid_body, right_body) = {
  block[
    #box(width: 1fr)[
      #align(left)[
        #left_body
      ]
    ]
    #box(width: 1fr)[
      #align(center)[
        #mid_body
      ]
    ]
    #box(width: 1fr)[
      #align(right)[
        #right_body
      ]
    ]
  ]
}

/// Right section for the justified headers
/// - body (content): The body of the right header
#let secondary-right-header(body) = {
  context {
    set text(
      size: 10pt,
      weight: "thin",
      style: "italic",
      fill: state-color-accent.get(),
    )
    body
  }
}

/// Right section of a tertiaty headers.
/// - body (content): The body of the right header
#let tertiary-right-header(body) = {
  set text(
    weight: "light",
    size: 9pt,
    style: "italic",
    fill: color-gray,
  )
  body
}

/// Justified header that takes a primary section and a secondary section. The primary section is on the left and the secondary section is on the right.
/// - primary (content): The primary section of the header
/// - secondary (content): The secondary section of the header
#let justified-header(primary, secondary) = {
  set block(
    above: 0.7em,
    below: 0.7em,
  )
  pad[
    #__justify_align[
      #set text(
        size: 12pt,
        weight: "bold",
        fill: color-darkgray,
      )
      #primary
    ][
      #secondary-right-header[#secondary]
    ]
  ]
}

/// Justified header that takes a primary section and a secondary section. The primary section is on the left and the secondary section is on the right. This is a smaller header compared to the `justified-header`.
/// - primary (content): The primary section of the header
/// - secondary (content): The secondary section of the header
#let secondary-justified-header(primary, secondary) = {
  __justify_align[
    #set text(
      size: 10pt,
      weight: "regular",
      fill: color-gray,
    )
    #primary
  ][
    #tertiary-right-header[#secondary]
  ]
}

//------------------------------------------------------------------------------
// Header
//------------------------------------------------------------------------------

#let create-header-name(
  firstname: "",
  lastname: "",
) = {
  context {
    pad(bottom: 5pt)[
      #block[
        #set text(
          size: 32pt,
          style: "normal",
          font: state-font-header.get(),
        )
        #text(fill: color-gray, weight: "thin")[#firstname]
        #text(weight: "bold")[#lastname]
      ]
    ]
  }
}

#let create-header-position(
  position: "",
) = {
  set block(
    above: 0.75em,
    below: 0.75em,
  )

  context {
    set text(
      state-color-accent.get(),
      size: 9pt,
      weight: "regular",
    )

    smallcaps[
      #position
    ]
  }
}

#let create-header-address(
  address: "",
) = {
  set block(
    above: 0.75em,
    below: 0.75em,
  )
  set text(
    color-lightgray,
    size: 9pt,
    style: "italic",
  )

  block[#address]
}

#let create-header-contacts(
  contacts: (),
) = {
  let separator = box(width: 2pt)
  if (contacts.len() > 1) {
    block[
      #set text(
        size: 9pt,
        weight: "regular",
        style: "normal",
      )
      #align(horizon)[
        #for contact in contacts [
          #set box(height: 9pt)
          #box[#parse_icon_string(contact.icon) #link(contact.url)[#contact.text]]
          #separator
        ]
      ]
    ]
  }
}

#let create-header-info(
  firstname: "",
  lastname: "",
  position: "",
  address: "",
  contacts: (),
  align-header: center,
) = {
  align(align-header)[
    #create-header-name(firstname: firstname, lastname: lastname)
    #create-header-position(position: position)
    #create-header-address(address: address)
    #create-header-contacts(contacts: contacts)
  ]
}

#let create-header-image(
  profile-photo: "",
) = {
  if profile-photo.len() > 0 {
    block(
      above: 15pt,
      stroke: none,
      radius: 9999pt,
      clip: true,
      image(
        fit: "contain",
        profile-photo,
      ),
    )
  }
}

#let create-header(
  firstname: "",
  lastname: "",
  position: "",
  address: "",
  contacts: (),
  profile-photo: "",
) = {
  if profile-photo.len() > 0 {
    block[
      #box(width: 5fr)[
        #create-header-info(
          firstname: firstname,
          lastname: lastname,
          position: position,
          address: address,
          contacts: contacts,
          align-header: left,
        )
      ]
      #box(width: 1fr)[
        #create-header-image(profile-photo: profile-photo)
      ]
    ]
  } else {
    create-header-info(
      firstname: firstname,
      lastname: lastname,
      position: position,
      address: address,
      contacts: contacts,
      align-header: center,
    )
  }
}

//------------------------------------------------------------------------------
// Resume Entries
//------------------------------------------------------------------------------

#let resume-item(body) = {
  set text(
    size: 10pt,
    style: "normal",
    weight: "light",
    fill: color-darknight,
  )
  set par(leading: 0.65em)
  set list(indent: 1em)
  body
}

#let resume-entry(
  title: none,
  location: "",
  date: "",
  description: "",
) = {
  pad[
    #justified-header(title, location)
    #secondary-justified-header(description, date)
  ]
}

//------------------------------------------------------------------------------
// Resume Template
//------------------------------------------------------------------------------

#let resume(
  title: "CV",
  author: (:),
  date: datetime.today().display("[month repr:long] [day], [year]"),
  profile-photo: "",
  font-header: "Roboto",
  font-text: "Source Sans 3",
  color-accent: rgb("#dc3522"),
  color-link: color-darknight,
  title-meta: none,
  author-meta: none,
  body,
) = {
  // Set states ----------------------------------------------------------------
  state-font-header.update(font-header)
  state-font-text.update(font-text)
  state-color-accent.update(color-accent)
  state-color-link.update(color-link)

  // Set document metadata -----------------------------------------------------
  set document(
    title: title-meta,
    author: author-meta,
  )

  set text(
    font: (font-text),
    size: 11pt,
    fill: color-darkgray,
    fallback: true,
  )

  set page(
    paper: "a4",
    margin: (left: 15mm, right: 15mm, top: 10mm, bottom: 10mm),
    footer: context [
      #set text(
        fill: gray,
        size: 8pt,
      )
      #__justify_align_3[
        #smallcaps[#date]
      ][
        #smallcaps[
          #author.firstname
          #author.lastname
          #sym.dot.c
          CV
        ]
      ][
        #counter(page).display()
      ]
    ],
  )

  // set paragraph spacing

  set heading(
    numbering: none,
    outlined: false,
  )

  show heading.where(level: 1): it => [
    #set block(
      above: 1.5em,
      below: 1em,
    )
    
    #set text(
        size: 16pt,
        weight: "regular",
    )

    #context {
      align(left)[
        #text[#strong[#text(state-color-accent.get())[#it.body.text.slice(0, 3)]#text(
            color-darkgray,
          )[#it.body.text.slice(3)]]]
        #box(width: 1fr, line(length: 100%))
      ]
    }
  ]

  show heading.where(level: 2): it => {
    set text(
      color-middledarkgray,
      size: 12pt,
      weight: "thin",
    )
    it.body
  }

  show heading.where(level: 3): it => {
    set text(
      size: 10pt,
      weight: "regular",
      fill: color-gray,
    )
    smallcaps[#it.body]
  }

  // Other settings
  show link: set text(fill: color-link)

  // Contents
  create-header(
    firstname: author.firstname,
    lastname: author.lastname,
    position: author.position,
    address: author.address,
    contacts: author.contacts,
    profile-photo: profile-photo,
  )
  body
}

#let brand-color = (:)
#let brand-color-background = (:)
#let brand-logo = (:)

#set page(
  paper: "us-letter",
  margin: (x: 1.25in, y: 1.25in),
  numbering: "1",
  columns: 1,
)

#show: resume.with(
  title: [Taller],
  title-meta: "Taller",
)

#Skylighting(([#CommentTok("---");],
[#AnnotationTok("title:");#CommentTok(" \"CV de Harry Potter\"");],
[#AnnotationTok("author:");],
[#CommentTok("  firstname: Harry");],
[#CommentTok("  lastname: Potter");],
[#CommentTok("  address: \"En algún lado\"");],
[#CommentTok("  position: \"Analista de datos ・ Profesor\"");],
[#CommentTok("  contacts:");],
[#CommentTok("    - icon: fa envelope");],
[#CommentTok("      text: hp@gmail.com");],
[#CommentTok("      url: \"mailto:ahp@gmail.com\"");],
[#CommentTok("    - icon: assets/icon/bi-house-fill.svg");],
[#CommentTok("      text: miportfolio.com");],
[#CommentTok("      url: https://miportfolio.com");],
[#CommentTok("    - icon: fa brands orcid");],
[#CommentTok("      text: 0000-0000-0000-0000");],
[#CommentTok("      url: https://orcid.org/0000-0000-0000-0000");],
[#CommentTok("    - icon: fa brands github");],
[#CommentTok("      text: GitHub");],
[#CommentTok("      url: https://github.com/harrypotter");],
[#CommentTok("    - icon: fa brands linkedin");],
[#CommentTok("      text: LinkedIn");],
[#CommentTok("      url: https://linkedin.com/in/harrypotter");],
[#CommentTok("    - icon: fa brands x-twitter");],
[#CommentTok("      text: twitter");],
[#CommentTok("      url: https://twitter.com/poterh");],
[#AnnotationTok("format:");#CommentTok(" awesomecv-typst");],
[#AnnotationTok("brand:");],
[#CommentTok("  typography: ");],
[#CommentTok("    fonts:");],
[#CommentTok("      - family: Roboto");],
[#CommentTok("        source: google");],
[#CommentTok("        weight: [100, 400, 700]");],
[#CommentTok("      - family: Source Sans 3");],
[#CommentTok("        source: google");],
[#CommentTok("        weight: [100, 400, 700]");],
[#CommentTok("        style: [normal, italic]");],
[#CommentTok("    base: Source Sans 3");],
[#CommentTok("  color:");],
[#CommentTok("    primary: \"#fd8e73\"");],
[#CommentTok("    link: \"#771822\"");],
[#CommentTok("  defaults: ");],
[#CommentTok("    awesomecv-typst:");],
[#CommentTok("      font-header: Roboto");],
[#AnnotationTok("execute:");#CommentTok(" ");],
[#CommentTok("  echo: false");],
[#CommentTok("  warning: false");],
[#CommentTok("---");],
[],
[#FunctionTok("## Educación");],
[],
[],
[#InformationTok("```{.r .cell-code}");],
[#FunctionTok("library");#NormalTok("(typstcv)");],));
#Skylighting(([#NormalTok("Warning: package 'typstcv' was built under R version 4.4.3");],));
#Skylighting(([#FunctionTok("library");#NormalTok("(tidyverse)");],));
#Skylighting(([#NormalTok("Warning: package 'ggplot2' was built under R version 4.4.3");],));
#Skylighting(([#NormalTok("Warning: package 'purrr' was built under R version 4.4.3");],));
#Skylighting(([#NormalTok("Warning: package 'dplyr' was built under R version 4.4.3");],));
#Skylighting(([#NormalTok("── Attaching core tidyverse packages ──────────────────────── tidyverse 2.0.0 ──");],
[#NormalTok("✔ dplyr     1.1.4     ✔ readr     2.1.5");],
[#NormalTok("✔ forcats   1.0.0     ✔ stringr   1.5.1");],
[#NormalTok("✔ ggplot2   3.5.2     ✔ tibble    3.2.1");],
[#NormalTok("✔ lubridate 1.9.3     ✔ tidyr     1.3.1");],
[#NormalTok("✔ purrr     1.0.4     ");],
[#NormalTok("── Conflicts ────────────────────────────────────────── tidyverse_conflicts() ──");],
[#NormalTok("✖ dplyr::filter() masks stats::filter()");],
[#NormalTok("✖ dplyr::lag()    masks stats::lag()");],
[#NormalTok("ℹ Use the conflicted package (<http://conflicted.r-lib.org/>) to force all conflicts to become errors");],));
#Skylighting(([#NormalTok("df_cv ");#OtherTok("<-");#NormalTok(" readxl");#SpecialCharTok("::");#FunctionTok("read_excel");#NormalTok("(");#StringTok("'harry_potter_cv_es.xlsx'");#NormalTok(") ");#SpecialCharTok("|>");#NormalTok(" ");],
[#NormalTok("  ");#FunctionTok("mutate");#NormalTok("(");#AttributeTok("start =");#NormalTok(" ");#FunctionTok("as_date");#NormalTok("(start),");],
[#AttributeTok("end =");#NormalTok(" ");#FunctionTok("as_date");#NormalTok("(end)) ");#SpecialCharTok("|>");#NormalTok(" ");],
[#NormalTok("  ");#FunctionTok("drop_na");#NormalTok("(start)");],
[],
[#NormalTok("df_cv ");#SpecialCharTok("|>");#NormalTok(" ");],
[#NormalTok("  ");#FunctionTok("filter");#NormalTok("(section ");#SpecialCharTok("==");#NormalTok(" ");#StringTok("'educacion'");#NormalTok(") ");#SpecialCharTok("|>");],
[#NormalTok("  ");#FunctionTok("format_date");#NormalTok("(");#AttributeTok("end =");#NormalTok(" ");#StringTok("\"end\"");#NormalTok(", ");#AttributeTok("sort_by =");#NormalTok(" ");#StringTok("\"start\"");#NormalTok(") ");#SpecialCharTok("|>");],
[#NormalTok("  ");#FunctionTok("resume_entry");#NormalTok("(");#AttributeTok("title =");#NormalTok(" ");#StringTok("\"role\"");#NormalTok(",");],
[#NormalTok("               ");#AttributeTok("description =");#NormalTok(" ");#StringTok("\"institution\"");#NormalTok(",");],
[#NormalTok("               ");#AttributeTok("details =");#NormalTok(" ");#StringTok("\"descripcion\"");#NormalTok(")");],));
#resume-entry(title: "Graduado – Programa de Formación de Aurores",location: "Londres, Reino Unido",date: "sept 1998 - jun 2001",description: "Oficina de Aurores – Ministerio de Magia",)
#resume-item[
- 
]
#resume-entry(title: "A.N.E.A.S. – Colegio Hogwarts",location: "Escocia, Reino Unido",date: "sept 1991 - jun 1998",description: "Colegio Hogwarts de Magia y Hechicería",)
#resume-item[
- 
]
= Experiencia laboral
<experiencia-laboral>
#Skylighting(([#NormalTok("df_cv ");#SpecialCharTok("|>");],
[#NormalTok("  ");#FunctionTok("filter");#NormalTok("(section ");#SpecialCharTok("==");#NormalTok(" ");#StringTok("'experiencia_laboral'");#NormalTok(") ");#SpecialCharTok("|>");#NormalTok(" ");],
[#NormalTok("  ");#FunctionTok("format_date");#NormalTok("(");#AttributeTok("end =");#NormalTok(" ");#StringTok("\"end\"");#NormalTok(",");],
[#NormalTok("   ");#AttributeTok("sort_by =");#NormalTok(" ");#StringTok("\"start\"");#NormalTok(",");],
[#NormalTok("  ");#AttributeTok("date_format =");#NormalTok(" ");#StringTok("\"%Y\"");#NormalTok(",");],
[#NormalTok("  ");#AttributeTok("sep =");#NormalTok(" ");#StringTok("\"->\"");#NormalTok(",");],
[#NormalTok("    ) ");#SpecialCharTok("|>");],
[#NormalTok("  typstcv");#SpecialCharTok("::");#FunctionTok("resume_entry");#NormalTok("(");#AttributeTok("title =");#NormalTok(" ");#StringTok("\"role\"");#NormalTok(",");],
[#NormalTok("               ");#AttributeTok("description =");#NormalTok(" ");#StringTok("\"institution\"");#NormalTok(")");],));
#resume-entry(title: "Profesor de Defensa (temporal)",location: "Escocia, Reino Unido",date: "2013->2013",description: "Colegio Hogwarts de Magia y Hechicería",)
#resume-entry(title: "Jefe de Aurores",location: "Londres, Reino Unido",date: "2007->2019",description: "Oficina de Aurores – Ministerio de Magia",)
#resume-entry(title: "Auror Senior",location: "Londres, Reino Unido",date: "2001->2006",description: "Oficina de Aurores – Ministerio de Magia",)
= Experiencia Docente
<experiencia-docente>
#Skylighting(([#NormalTok("df_cv ");#SpecialCharTok("|>");],
[#NormalTok("  ");#FunctionTok("filter");#NormalTok("(section ");#SpecialCharTok("==");#NormalTok(" ");#StringTok("'experiencia_docente'");#NormalTok(") ");#SpecialCharTok("|>");#NormalTok(" ");],
[#NormalTok("  ");#FunctionTok("format_date");#NormalTok("(");#AttributeTok("end =");#NormalTok(" ");#StringTok("\"end\"");#NormalTok(",");],
[#NormalTok("   ");#AttributeTok("sort_by =");#NormalTok(" ");#StringTok("\"start\"");#NormalTok(",");],
[#NormalTok("  ");#AttributeTok("date_format =");#NormalTok(" ");#StringTok("\"%Y\"");#NormalTok(",");],
[#NormalTok("  ");#AttributeTok("sep =");#NormalTok(" ");#StringTok("\"->\"");#NormalTok(",");],
[#NormalTok("    ) ");#SpecialCharTok("|>");],
[#NormalTok("  typstcv");#SpecialCharTok("::");#FunctionTok("resume_entry");#NormalTok("(");#AttributeTok("title =");#NormalTok(" ");#StringTok("\"role\"");#NormalTok(",");],
[#NormalTok("               ");#AttributeTok("description =");#NormalTok(" ");#StringTok("\"institution\"");#NormalTok(",");],
[#NormalTok("               ");#AttributeTok("details =");#NormalTok(" ");#FunctionTok("c");#NormalTok("(");#StringTok("\"description\"");#NormalTok("),");],
[#NormalTok("               ");#AttributeTok("location =");#NormalTok(" ");#StringTok("\"location\"");#NormalTok(")");],));
#resume-entry(title: "Docente invitado – Evaluación de Amenazas",location: "Londres, Reino Unido",date: "2018->2018",description: "Academia de Artes Dramáticas de Hechicería",)
#resume-item[
- Dictó dos clases magistrales sobre evaluación práctica de amenazas para magos y brujas en entornos de alto riesgo.
]
#resume-entry(title: "Ejército de Dumbledore – Fundador e Instructor",location: "Escocia, Reino Unido",date: "1995->1996",description: "Colegio Hogwarts de Magia y Hechicería",)
#resume-item[
- Fundó y lideró un grupo estudiantil de defensa de 28 miembros. Diseñó el programa, coordinó las sesiones y evaluó el progreso en condiciones institucionales adversas.
]
= Investigación
<investigación>
#Skylighting(([#NormalTok("df_cv ");#SpecialCharTok("|>");#NormalTok(" ");],
[#NormalTok("  ");#FunctionTok("filter");#NormalTok("(section ");#SpecialCharTok("==");#NormalTok(" ");#StringTok("'investigacion'");#NormalTok(")");#SpecialCharTok("|>");],
[#NormalTok("  ");#FunctionTok("format_date");#NormalTok("(");#AttributeTok("end =");#NormalTok(" ");#StringTok("\"end\"");#NormalTok(", ");#AttributeTok("sort_by =");#NormalTok(" ");#StringTok("\"start\"");#NormalTok(") ");#SpecialCharTok("|>");],
[#NormalTok("  ");#FunctionTok("resume_entry");#NormalTok("(");#AttributeTok("title =");#NormalTok(" ");#StringTok("\"role\"");#NormalTok(",");],
[#NormalTok("               ");#AttributeTok("description =");#NormalTok(" ");#StringTok("\"project\"");#NormalTok(",");],
[#NormalTok("               ");#AttributeTok("location =");#NormalTok(" ");#StringTok("\"institution\"");#NormalTok(",");],
[#NormalTok("               ");#AttributeTok("details =");#NormalTok(" ");#StringTok("\"description\"");#NormalTok(",");],
[#NormalTok("               ");#AttributeTok("date =");#NormalTok(" ");#StringTok("\"start\"");#NormalTok(") ");],));
#resume-entry(title: "Investigador de campo",location: "División de Analítica de los Insondables",date: "ene 2020",description: "Modelado Predictivo de Amenazas con R",)
#resume-item[
- Lideró investigación exploratoria sobre el uso de modelos estadísticos (R, tidyverse, ggplot2) para anticipar actividad de magos oscuros. Produjo tres informes internos.
]
#resume-entry(title: "Consultor – Clasificación de Artefactos Oscuros",location: "Departamento de Misterios",date: "jun 2010",description: "Proyecto de Taxonomía de Amenazas Mágicas",)
#resume-item[
- Co-desarrolló un marco de clasificación para objetos malditos. Los resultados fueron adoptados como estándar ministerial en 2012.
]
\`\`\`
