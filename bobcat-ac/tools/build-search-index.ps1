<#
  build-search-index.ps1
  ----------------------------------------------------------------------------
  Regenerates the client-side search index for the bobcat-ac subsite:
      bobcat-ac/assets/search-index.json

  This is a static site with no build step and no Node, so the index is a
  plain JSON file the browser fetches once and searches in memory
  (see initSearch() in assets/js/main.js). Re-run this script whenever you
  add or edit a page under bobcat-ac/ so the search box stays current.

  Usage (from anywhere):
      powershell -ExecutionPolicy Bypass -File path\to\tools\build-search-index.ps1

  No dependencies — Windows PowerShell 5.1+. Indexes ONLY bobcat-ac; the
  Rudi-HQ homepage and any future subsites are intentionally out of scope.
#>

$ErrorActionPreference = 'Stop'

# tools/ lives directly under the bobcat-ac root, so the root is our parent.
$root    = Split-Path -Parent $PSScriptRoot
$outFile = Join-Path $root 'assets\search-index.json'

# Turn a chunk of HTML into clean, searchable plain text.
function Convert-HtmlToText {
    param([string]$html)
    if (-not $html) { return '' }
    $t = $html
    $t = [regex]::Replace($t, '(?is)<script.*?</script>', ' ')
    $t = [regex]::Replace($t, '(?is)<style.*?</style>',  ' ')
    $t = [regex]::Replace($t, '(?s)<!--.*?-->',          ' ')
    $t = [regex]::Replace($t, '(?s)<[^>]+>',             ' ')   # strip tags
    # Decode the handful of entities actually used across the site.
    $map = @{
        '&nbsp;'=' '; '&amp;'='&'; '&lt;'='<'; '&gt;'='>'; '&quot;'='"';
        '&#39;'="'"; '&rsquo;'="'"; '&lsquo;'="'"; '&ldquo;'='"'; '&rdquo;'='"';
        '&mdash;'='-'; '&ndash;'='-'; '&times;'='x'; '&deg;'='deg'; '&hellip;'='...'
    }
    foreach ($k in $map.Keys) { $t = $t -replace [regex]::Escape($k), $map[$k] }
    $t = [regex]::Replace($t, '\s+', ' ').Trim()
    return $t
}

# Must produce EXACTLY the same output as slugify() in assets/js/main.js for
# the same input text. That JS function assigns real DOM ids to .section-title
# headings at page-load time; this one computes the anchor a search result
# links to (page.html#slug). Neither side talks to the other at runtime — they
# only land on the same id because both run the identical rule on the
# identical heading text. Change one, change the other, or every existing
# deep link in the index silently stops landing on its target.
function Get-Slug {
    param([string]$text)
    $s = $text.ToLower().Trim()
    $s = [regex]::Replace($s, '[^a-z0-9]+', '-')
    $s = $s.Trim('-')
    return $s
}

# All pages under bobcat-ac, excluding build assets themselves.
$files = Get-ChildItem -Path $root -Recurse -Filter *.html |
    Where-Object { $_.FullName -notmatch '\\assets\\' }

$entries = New-Object System.Collections.Generic.List[object]

foreach ($f in $files) {
    $raw = Get-Content -Raw -Encoding UTF8 -Path $f.FullName

    # URL relative to the bobcat-ac root, forward slashes (browser-friendly).
    $rel = $f.FullName.Substring($root.Length).TrimStart('\', '/') -replace '\\', '/'

    # Human title: prefer the on-page .page-title, fall back to the cleaned <title>.
    $docTitle = ''
    if ($raw -match '(?is)<title>(.*?)</title>') { $docTitle = Convert-HtmlToText $matches[1] }
    # \p{Pd} = any Unicode dash (hyphen / en-dash / em-dash) so this script
    # stays pure-ASCII and doesn't depend on how PS decodes its own source.
    $docTitle = $docTitle -replace '\s*\p{Pd}\s*Bobcat AC Training.*$', ''
    $docTitle = $docTitle -replace '\s*\p{Pd}\s*Home\s*$', ''

    $pageTitle = ''
    if ($raw -match '(?is)<div class="page-title">(.*?)</div>') { $pageTitle = Convert-HtmlToText $matches[1] }
    $title = if ($pageTitle) { $pageTitle } elseif ($docTitle) { $docTitle } else { $rel }

    # Breadcrumb context (shown under each result), read from the header data attr.
    $breadcrumb = ''
    if ($raw -match 'data-breadcrumb="([^"]*)"') { $breadcrumb = $matches[1] }

    # Body HTML: prefer <main>; otherwise strip the shared nav/header chrome so
    # sidebar link text doesn't pollute every page's index. Sections are found
    # within THIS scoped HTML (not $raw) so slice offsets below line up with
    # each section's own boundaries and never spill into nav/header markup.
    $bodyHtml = $raw
    if ($raw -match '(?is)<main[^>]*>(.*?)</main>') {
        $bodyHtml = $matches[1]
    } else {
        $bodyHtml = [regex]::Replace($bodyHtml, '(?is)<nav.*?</nav>',       ' ')
        $bodyHtml = [regex]::Replace($bodyHtml, '(?is)<header.*?</header>', ' ')
    }
    $text = Convert-HtmlToText $bodyHtml
    if ($text.Length -gt 5000) { $text = $text.Substring(0, 5000) }

    # One entry per .section-title heading: {id, title, text}. "text" is
    # everything between this heading and the next one (or end of body) —
    # i.e. that section's own content, for section-scoped search matching
    # and result snippets. "id" is the anchor assignSectionIds() will give
    # the matching heading in the browser (see Get-Slug's doc comment).
    $sections = New-Object System.Collections.Generic.List[object]
    $slugCounts = @{}
    $titleMatches = [regex]::Matches($bodyHtml, '(?is)<div class="section-title">(.*?)</div>')
    for ($i = 0; $i -lt $titleMatches.Count; $i++) {
        $m = $titleMatches[$i]
        $headingText = Convert-HtmlToText $m.Groups[1].Value
        if (-not $headingText) { continue }

        $slug = Get-Slug $headingText
        if (-not $slug) { $slug = 'section' }
        if ($slugCounts.ContainsKey($slug)) {
            $slugCounts[$slug] = $slugCounts[$slug] + 1
            $slug = "$slug-$($slugCounts[$slug])"
        } else {
            $slugCounts[$slug] = 1
        }

        $sectionStart = $m.Index + $m.Length
        $sectionEnd = if ($i + 1 -lt $titleMatches.Count) { $titleMatches[$i + 1].Index } else { $bodyHtml.Length }
        $sectionText = Convert-HtmlToText ($bodyHtml.Substring($sectionStart, $sectionEnd - $sectionStart))
        if ($sectionText.Length -gt 600) { $sectionText = $sectionText.Substring(0, 600) }

        $sections.Add([pscustomobject]@{
            id    = $slug
            title = $headingText
            text  = $sectionText
        })
    }

    $entries.Add([pscustomobject]@{
        url        = $rel
        title      = $title
        breadcrumb = $breadcrumb
        sections   = $sections.ToArray()
        text       = $text
    })
}

# Pipe (not -InputObject) to dodge a PS 5.1 ConvertTo-Json quirk, and force a
# JSON array even when a single page matches (PS 5.1 unwraps a lone object).
$json = ($entries.ToArray() | ConvertTo-Json -Depth 6)
if ($entries.Count -le 1) { $json = "[$json]" }

# Write UTF-8 WITHOUT a BOM — a BOM breaks JSON.parse in the browser.
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllText($outFile, $json, $utf8NoBom)

Write-Host "Wrote $($entries.Count) entries to $outFile"
