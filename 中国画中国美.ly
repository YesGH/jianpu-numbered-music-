\version "2.24.1"
#(set-global-staff-size 20)

% un-comment the next line to remove Lilypond tagline:
 \header { tagline="2025.1.15" }

% comment out the next line if you're debugging jianpu-ly
% (but best leave it un-commented in production, since
% the point-and-click locations won't go to the user input)
\pointAndClickOff

\paper {
  print-all-headers = ##t %% allow per-score headers

  % un-comment the next line for A5:
  % #(set-default-paper-size "a5" )

  % un-comment the next line for no page numbers:
  % print-page-number = ##f

  % un-comment the next 3 lines for a binding edge:
  % two-sided = ##t
  % inner-margin = 20\mm
  % outer-margin = 10\mm

  % un-comment the next line for a more space-saving header layout:
  % scoreTitleMarkup = \markup { \center-column { \fill-line { \magnify #1.5 { \bold { \fromproperty #'header:dedication } } \magnify #1.5 { \bold { \fromproperty #'header:title } } \fromproperty #'header:composer } \fill-line { \fromproperty #'header:instrument \fromproperty #'header:subtitle \smaller{\fromproperty #'header:subsubtitle } } } }

  % Might need to enforce a minimum spacing between systems, especially if lyrics are below the last staff in a system and numbers are on the top of the next
  system-system-spacing = #'((basic-distance . 7) (padding . 5) (stretchability . 1e7))
  score-markup-spacing = #'((basic-distance . 9) (padding . 5) (stretchability . 1e7))
  score-system-spacing = #'((basic-distance . 9) (padding . 5) (stretchability . 1e7))
  markup-system-spacing = #'((basic-distance . 2) (padding . 2) (stretchability . 0))
}

%% 2-dot and 3-dot articulations
#(append! default-script-alist
   (list
    `(two-dots
       . (
           (stencil . ,ly:text-interface::print)
           (text . ,#{ \markup \override #'(font-encoding . latin1) \center-align \bold ":" #})
           (padding . 0.20)
           (avoid-slur . inside)
           (direction . ,UP)))))
#(append! default-script-alist
   (list
    `(three-dots
       . (
           (stencil . ,ly:text-interface::print)
           (text . ,#{ \markup \override #'(font-encoding . latin1) \center-align \bold "⋮" #})
           (padding . 0.30)
           (avoid-slur . inside)
           (direction . ,UP)))))
"two-dots" =
#(make-articulation 'two-dots)

"three-dots" =
#(make-articulation 'three-dots)

\layout {
  \context {
    \Score
    scriptDefinitions = #default-script-alist
  }
}

note-mod =
#(define-music-function
     (text note)
     (markup? ly:music?)
   #{
     \tweak NoteHead.stencil #ly:text-interface::print
     \tweak NoteHead.text
        \markup \lower #0.5 \sans \bold #text
     \tweak Rest.stencil #ly:text-interface::print
     \tweak Rest.text
        \markup \lower #0.5 \sans \bold #text
     #note
   #})
#(define (flip-beams grob)
   (ly:grob-set-property!
    grob 'stencil
    (ly:stencil-translate
     (let* ((stl (ly:grob-property grob 'stencil))
            (centered-stl (ly:stencil-aligned-to stl Y DOWN)))
       (ly:stencil-translate-axis
        (ly:stencil-scale centered-stl 1 -1)
        (* (- (car (ly:stencil-extent stl Y)) (car (ly:stencil-extent centered-stl Y))) 0) Y))
     (cons 0 -0.8))))

%=======================================================
#(define-event-class 'jianpu-grace-curve-event 'span-event)

#(define (add-grob-definition grob-name grob-entry)
   (set! all-grob-descriptions
         (cons ((@@ (lily) completize-grob-entry)
                (cons grob-name grob-entry))
               all-grob-descriptions)))

#(define (jianpu-grace-curve-stencil grob)
   (let* ((elts (ly:grob-object grob 'elements))
          (refp-X (ly:grob-common-refpoint-of-array grob elts X))
          (X-ext (ly:relative-group-extent elts refp-X X))
          (refp-Y (ly:grob-common-refpoint-of-array grob elts Y))
          (Y-ext (ly:relative-group-extent elts refp-Y Y))
          (direction (ly:grob-property grob 'direction RIGHT))
          (x-start (* 0.5 (+ (car X-ext) (cdr X-ext))))
          (y-start (+ (car Y-ext) 0.32))
          (x-start2 (if (eq? direction RIGHT)(+ x-start 0.5)(- x-start 0.5)))
          (x-end (if (eq? direction RIGHT)(+ (cdr X-ext) 0.2)(- (car X-ext) 0.2)))
          (y-end (- y-start 0.5))
          (stil (ly:make-stencil `(path 0.1
                                        (moveto ,x-start ,y-start
                                         curveto ,x-start ,y-end ,x-start ,y-end ,x-start2 ,y-end
                                         lineto ,x-end ,y-end))
                                  X-ext
                                  Y-ext))
          (offset (ly:grob-relative-coordinate grob refp-X X)))
     (ly:stencil-translate-axis stil (- offset) X)))

#(add-grob-definition
  'JianpuGraceCurve
  `(
     (stencil . ,jianpu-grace-curve-stencil)
     (meta . ((class . Spanner)
              (interfaces . ())))))

#(define jianpu-grace-curve-types
   '(
      (JianpuGraceCurveEvent
       . ((description . "Used to signal where curve encompassing music start and stop.")
          (types . (general-music jianpu-grace-curve-event span-event event))
          ))
      ))

#(set!
  jianpu-grace-curve-types
  (map (lambda (x)
         (set-object-property! (car x)
           'music-description
           (cdr (assq 'description (cdr x))))
         (let ((lst (cdr x)))
           (set! lst (assoc-set! lst 'name (car x)))
           (set! lst (assq-remove! lst 'description))
           (hashq-set! music-name-to-property-table (car x) lst)
           (cons (car x) lst)))
    jianpu-grace-curve-types))

#(set! music-descriptions
       (append jianpu-grace-curve-types music-descriptions))

#(set! music-descriptions
       (sort music-descriptions alist<?))


#(define (add-bound-item spanner item)
   (if (null? (ly:spanner-bound spanner LEFT))
       (ly:spanner-set-bound! spanner LEFT item)
       (ly:spanner-set-bound! spanner RIGHT item)))

jianpuGraceCurveEngraver =
#(lambda (context)
   (let ((span '())
         (finished '())
         (current-event '())
         (event-start '())
         (event-stop '()))
     `(
       (listeners
        (jianpu-grace-curve-event .
          ,(lambda (engraver event)
             (if (= START (ly:event-property event 'span-direction))
                 (set! event-start event)
                 (set! event-stop event)))))

       (acknowledgers
        (note-column-interface .
          ,(lambda (engraver grob source-engraver)
             (if (ly:spanner? span)
                 (begin
                  (ly:pointer-group-interface::add-grob span 'elements grob)
                  (add-bound-item span grob)))
             (if (ly:spanner? finished)
                 (begin
                  (ly:pointer-group-interface::add-grob finished 'elements grob)
                  (add-bound-item finished grob)))))
        (inline-accidental-interface .
          ,(lambda (engraver grob source-engraver)
             (if (ly:spanner? span)
                 (begin
                  (ly:pointer-group-interface::add-grob span 'elements grob)))
             (if (ly:spanner? finished)
                 (ly:pointer-group-interface::add-grob finished 'elements grob))))
        (script-interface .
          ,(lambda (engraver grob source-engraver)
             (if (ly:spanner? span)
                 (begin
                  (ly:pointer-group-interface::add-grob span 'elements grob)))
             (if (ly:spanner? finished)
                 (ly:pointer-group-interface::add-grob finished 'elements grob)))))
       
       (process-music .
         ,(lambda (trans)
            (if (ly:stream-event? event-stop)
                (if (null? span)
                    (ly:warning "No start to this curve.")
                    (begin
                     (set! finished span)
                     (ly:engraver-announce-end-grob trans finished event-start)
                     (set! span '())
                     (set! event-stop '()))))
            (if (ly:stream-event? event-start)
                (begin
                 (set! span (ly:engraver-make-grob trans 'JianpuGraceCurve event-start))
                 (set! event-start '())))))
       
       (stop-translation-timestep .
         ,(lambda (trans)
            (if (and (ly:spanner? span)
                     (null? (ly:spanner-bound span LEFT)))
                (ly:spanner-set-bound! span LEFT
                  (ly:context-property context 'currentMusicalColumn)))
            (if (ly:spanner? finished)
                (begin
                 (if (null? (ly:spanner-bound finished RIGHT))
                     (ly:spanner-set-bound! finished RIGHT
                       (ly:context-property context 'currentMusicalColumn)))
                 (set! finished '())
                 (set! event-start '())
                 (set! event-stop '())))))
       
       (finalize
        (lambda (trans)
          (if (ly:spanner? finished)
              (begin
               (if (null? (ly:spanner-bound finished RIGHT))
                   (set! (ly:spanner-bound finished RIGHT)
                         (ly:context-property context 'currentMusicalColumn)))
               (set! finished '())))))
       )))

jianpuGraceCurveStart =
#(make-span-event 'JianpuGraceCurveEvent START)

jianpuGraceCurveEnd =
#(make-span-event 'JianpuGraceCurveEvent STOP)
%===========================================================

%{ The jianpu-ly input was:
%%\tempo: 4=90
title=中国画中国美
poet= 抄谱:ye
composer= 赵真词曲
arranger= 成老师配器

1=C
2/4
4=60
%WithStaff
NoIndent
chords=a2:m c2 g:m7 c  c2 a2:m f2 g2:m7 a2:m f2 d2:m g2:m7 c2 e2:m d2:m a2:m f2 c2 g2:m7 c1 c2 a2:m f2 g2:m7 a2:m f2 d2:m g2:m7 c2 e2:m d2:m g2:m7 f2 c2 g2:m7 c2 c2 c2 f2 d2 g2:m7 a2:m c2 d2 g2:m7 c2 f2 d2 g2:m7 a2:m c2 g2:m7 c1  a2:m c2 g2:m7 c1
%旋律右手
 q6 ^"右手高八度" s5 s6 q1' s1' s1' q5 q1' q5 q3 s2 s3 s5 s3 s2 s3 s6, s2 1 -  \break 
q0 s3 s2 q3 q5 q2 s2 ( s1 ) 1 q6,. s3 s2 ( s3 ) q6, 5, - q0 s1 s6, q1 q2 q3 s6 ( s1' ) s6 ( s5 ) q3 q1 s6, ( s1 ) s5 ( s6 ) s4 ( s3 ) 2 - \break 
q0 s3 s2 q3 q6 s5 ( s6 ) s3 ( s2 ) s3 ( q5. ) q2. s3 q5 q5, s1 ( d2 d1 6,. )  q0 s1 s6, q1 q2 q3 q6 5 q5, s5, ( s6, ) q3 q2 2 ( 1 ) ( 51'3' ) \arpeggio -  \break 
q0 s3 s2 q3 q5 q2 s2 ( s1 ) 1 q6,. s3 s2 ( s3 ) q6, 5, - q0 s1 s6, q1 q2 q3 s6 ( s1' ) s6 ( s5 ) q3 q1 s6, ( s1 ) s5 ( s6 ) s4 ( s3 ) 2 -  \break 
q0 s3 s2 q3 q6 s5 ( s6 ) s3 ( s2 ) q3 q5 q2. s3 s2 ( s3 ) q5, q1 ( 6,. )  q0 s1 s6, q1 q2 q3 s2 ( s3 ) s2 ( s3 ) q5 q2. s3 q3 q2 2 ( 1 ) ~ 1 - \break
q3 ^"右手八度音" s5 s6 s1' ( s2' ) q7 6 - q6 s2' s3' s1' ( s2' ) q6 5 -  q6 ^"右手高八度" s5 s6 q1' s1' s1' q5 s6 ( s1' ) q5 q3 q5. s6 q1' s6 ( s5 ) 2' - \break 
q3 ^"右手八度音" s5 s6 s1' ( s2' ) q7 6 - q6 s2' s3' s1' ( s2' ) q6 5 - q6 ^"右手高八度" s5 s6 q1' s1' s1' s5 ( s6 ) s3 ( s2 ) 3 q5 s6 s1' q7 q6 1' - ~ 1' - \break 
q6 s5 s6 q1' s1' s1' s5 ( s6 ) s3 ( s2 ) 3 q5 ^"右手八度音" s6 s1' g[s2'] q3' q6 1'  - - - |

H: \skip1 \skip1 \skip1 \skip1 \skip1 \skip1 \skip1 \skip1 \skip1 \skip1 \skip1 \skip1 \skip1 \skip1 \skip1 \skip1 \skip1 \skip1 \skip1 \skip1 山水流过丹青醉 谁对月举杯 \skip1 玉笔多情一幕 砂红四大家人美 \skip1  墨香描来江南雨 琴声在等谁 满纸云烟染峰秀 仙鹤画中飞 \skip1  粉彩蘸来一片暖 牡丹万花开 \skip1 羊毫勾来梅兰竹菊 君子心中爱 \skip1  梦中又画伞下情人 相亲和相爱 醒来再画春夏秋冬 家乡的等待 \skip1 画一幅中国画 \skip1 画一幅中国美 \skip1 画不尽中国的山山水水 看也能看醉 \skip1 画一幅中国画 \skip1 画一幅中国美 \skip1 画不尽浓浓的中国情 浓浓的中国味 \skip1  画不尽浓浓的中国情 浓浓的中国味

%左手伴奏
NextPart 316, \arpeggio - 315, \arpeggio - 5, 5,, s1, s5, s6, s5, 1 \break 
1  q5 q3 6, q3 q1 4, q1 q6, 5, q5 q2  316, \arpeggio  - 14, s6 s5 q3 16,2, \arpeggio  - s5 s2 s1 s6, 5, \break 
315, - 37,5, \arpeggio  - q2. s3 5, 316,. q316, q4, q1 4 q3, q1 3 2, q5, q5,, q1, s5, s6, q1 q2 3 - \break
q1 s5 s6 q5 q3 q6, s3 s2 q3 q1 q4, s3 s2 q3 q1 q5, s1 s2 q5 q5, q6, q1 3 q0 q1' q6 q5 q2 q6, 2, s5,, s5, s6, s1 5 \break 
315, - 37,5, \arpeggio  - q2. s3 5, q0 s3 s2 q1 q6, 4,1 - 1, 15, 5,2,5,, \arpeggio  - s1, s5, s6, s1 q2 q3 s5 s6 ^"右手" s1' s2' s6 s1' ^"右手" s2' s1' \break
s1,, s5,, s1, s3, s5, s3, s1, s5,, s4,, s1, s4, s6, s1 s6, s4, s1, s2,, s6,, s2, s#4, s6, s#4, s2, s6,, s5,, s5, s6, s1 5 6,, q316, q316, 1,, q315, q315, 2,, q#426, q#426,  6[ s5,, _"长琶音" s2, s5, s7, s2 s5 ] 6[ s5,  s2 s5 s7 s2' s5' ] \break
s1,, s5,, s1, s3, s5, s3, s1, s5,, s4,, s1, s4, s6, s1 s6, s4, s1, s2,, s6,, s2, s#4, s6, s#4, s2, s6,, s5,, s5, s6, s1 5 6,, q316, q316, 1,, 315,  5,,5, 5,,,5,, s1, s5, s6, s1 s2 s3 s5 s6 s1' s6 s5  s3 s2 s1 s6, s5, 316, - 315, - 5,,,5,,  47,5, \arpeggio 6[ s1,, _"长琶音四组" s5,, s1, s3, s5, s1 ] 6[ s1, s5, s1 s3 s5 s1' ] 6[ s1  s5 s1' s3' s5' s1'' ] 6[ s1' s5' s1'' s3'' s5'' s1''' ] |
%}


\score {
<< \override Score.BarNumber.break-visibility = #center-visible
\override Score.BarNumber.Y-offset = -1
\set Score.barNumberVisibility = #(every-nth-bar-number-visible 5)
\new ChordNames { \chordmode { a2:m c2 g:m7 c  c2 a2:m f2 g2:m7 a2:m f2 d2:m g2:m7 c2 e2:m d2:m a2:m f2 c2 g2:m7 c1 c2 a2:m f2 g2:m7 a2:m f2 d2:m g2:m7 c2 e2:m d2:m g2:m7 f2 c2 g2:m7 c2 c2 c2 f2 d2 g2:m7 a2:m c2 d2 g2:m7 c2 f2 d2 g2:m7 a2:m c2 g2:m7 c1  a2:m c2 g2:m7 c1 } }

%% === BEGIN JIANPU STAFF ===
    \new RhythmicStaff \with {
    \consists "Accidental_engraver" 
    % Get rid of the stave but not the barlines:
    \override StaffSymbol.line-count = #0 % tested in 2.15.40, 2.16.2, 2.18.0, 2.18.2, 2.20.0 and 2.22.2
    \override BarLine.bar-extent = #'(-2 . 2) % LilyPond 2.18: please make barlines as high as the time signature even though we're on a RhythmicStaff (2.16 and 2.15 don't need this although its presence doesn't hurt; Issue 3685 seems to indicate they'll fix it post-2.18)
    $(add-grace-property 'Voice 'Stem 'direction DOWN)
    $(add-grace-property 'Voice 'Slur 'direction UP)
    $(add-grace-property 'Voice 'Stem 'length-fraction 0.5)
    $(add-grace-property 'Voice 'Beam 'beam-thickness 0.1)
    $(add-grace-property 'Voice 'Beam 'length-fraction 0.3)
    $(add-grace-property 'Voice 'Beam 'after-line-breaking flip-beams)
    $(add-grace-property 'Voice 'Beam 'Y-offset 2.5)
    $(add-grace-property 'Voice 'NoteHead 'Y-offset 2.5)
    }
    { \new Voice="e" {
    \override Beam.transparent = ##f
    \override Stem.direction = #DOWN
    \override Tie.staff-position = #2.5
    \tupletUp
    \tieUp
    \override Stem.length-fraction = #0.5
    \override Beam.beam-thickness = #0.1
    \override Beam.length-fraction = #0.5
    \override Beam.after-line-breaking = #flip-beams
    \override Voice.Rest.style = #'neomensural % this size tends to line up better (we'll override the appearance anyway)
    \override Accidental.font-size = #-4
    \override TupletBracket.bracket-visibility = ##t
\set Voice.chordChanges = ##t %% 2.19 bug workaround

    \override Staff.TimeSignature.style = #'numbered
    \override Staff.Stem.transparent = ##t
     \mark \markup{1=C} \time 2/4 \tempo 4=60 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "6" a'8[
^"右手高八度" \set stemLeftBeamCount = #1
\set stemRightBeamCount = #2
 \note-mod "5" g'16
\set stemLeftBeamCount = #2
\set stemRightBeamCount = #2
 \note-mod "6" a'16]
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c''8^.[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #2
 \note-mod "1" c''16^.
\set stemLeftBeamCount = #2
\set stemRightBeamCount = #2
 \note-mod "1" c''16^.]
| %{ bar 2: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "5" g'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "1" c''8^.]
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "5" g'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "3" e'8]
| %{ bar 3: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #2
 \note-mod "2" d'16[
\set stemLeftBeamCount = #2
\set stemRightBeamCount = #2
 \note-mod "3" e'16
\set stemLeftBeamCount = #2
\set stemRightBeamCount = #2
 \note-mod "5" g'16
\set stemLeftBeamCount = #2
\set stemRightBeamCount = #2
 \note-mod "3" e'16]
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #2
 \note-mod "2" d'16[
\set stemLeftBeamCount = #2
\set stemRightBeamCount = #2
 \note-mod "3" e'16
\set stemLeftBeamCount = #2
\set stemRightBeamCount = #2
 \note-mod "6" a16-\tweak #'X-offset #0.6 _. 
\set stemLeftBeamCount = #2
\set stemRightBeamCount = #2
 \note-mod "2" d'16]
| %{ bar 4: %}
 \note-mod "1" c'4
 \note-mod "–" c'4 \break | %{ bar 5: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" r8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #2
 \note-mod "3" e'16
\set stemLeftBeamCount = #2
\set stemRightBeamCount = #2
 \note-mod "2" d'16]
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "3" e'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "5" g'8]
| %{ bar 6: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #2
 \note-mod "2" d'16
( \set stemLeftBeamCount = #2
\set stemRightBeamCount = #2
 \note-mod "1" c'16]
)  \note-mod "1" c'4 | %{ bar 7: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "6" a8.-\tweak #'X-offset #0.6 _. [
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #2
 \note-mod "3" e'16]
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #2
 \note-mod "2" d'16[
( \set stemLeftBeamCount = #2
\set stemRightBeamCount = #2
 \note-mod "3" e'16
) \set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "6" a8-\tweak #'X-offset #0.6 _. ]
| %{ bar 8: %}
 \note-mod "5" g4-\tweak #'Y-offset #-1.2 -\tweak #'X-offset #0.6 _. 
 \note-mod "–" g4 | %{ bar 9: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" r8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #2
 \note-mod "1" c'16
\set stemLeftBeamCount = #2
\set stemRightBeamCount = #2
 \note-mod "6" a16-\tweak #'X-offset #0.6 _. ]
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "2" d'8]
| %{ bar 10: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "3" e'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #2
 \note-mod "6" a'16
( \set stemLeftBeamCount = #2
\set stemRightBeamCount = #2
 \note-mod "1" c''16^.]
) \set stemLeftBeamCount = #0
\set stemRightBeamCount = #2
 \note-mod "6" a'16[
( \set stemLeftBeamCount = #2
\set stemRightBeamCount = #2
 \note-mod "5" g'16
) \set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "3" e'8]
| %{ bar 11: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #2
 \note-mod "6" a16-\tweak #'X-offset #0.6 _. 
( \set stemLeftBeamCount = #2
\set stemRightBeamCount = #2
 \note-mod "1" c'16]
) \set stemLeftBeamCount = #0
\set stemRightBeamCount = #2
 \note-mod "5" g'16[
( \set stemLeftBeamCount = #2
\set stemRightBeamCount = #2
 \note-mod "6" a'16
) \set stemLeftBeamCount = #2
\set stemRightBeamCount = #2
 \note-mod "4" f'16
( \set stemLeftBeamCount = #2
\set stemRightBeamCount = #2
 \note-mod "3" e'16]
) | %{ bar 12: %}
 \note-mod "2" d'4
 \note-mod "–" d'4 \break | %{ bar 13: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" r8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #2
 \note-mod "3" e'16
\set stemLeftBeamCount = #2
\set stemRightBeamCount = #2
 \note-mod "2" d'16]
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "3" e'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "6" a'8]
| %{ bar 14: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #2
 \note-mod "5" g'16[
( \set stemLeftBeamCount = #2
\set stemRightBeamCount = #2
 \note-mod "6" a'16
) \set stemLeftBeamCount = #2
\set stemRightBeamCount = #2
 \note-mod "3" e'16
( \set stemLeftBeamCount = #2
\set stemRightBeamCount = #2
 \note-mod "2" d'16]
) \set stemLeftBeamCount = #0
\set stemRightBeamCount = #2
 \note-mod "3" e'16[
( \set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "5" g'8.]
) | %{ bar 15: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8.[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #2
 \note-mod "3" e'16]
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "5" g'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "5" g8-\tweak #'X-offset #0.6 _. ]
| %{ bar 16: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #2
 \note-mod "1" c'16[
( \set stemLeftBeamCount = #2
\set stemRightBeamCount = #3
 \note-mod "2" d'32
\set stemLeftBeamCount = #3
\set stemRightBeamCount = #3
 \note-mod "1" c'32
]   \note-mod "6" a4.-\tweak #'Y-offset #-1.2 -\tweak #'X-offset #0.6 _. 
) | %{ bar 17: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" r8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #2
 \note-mod "1" c'16
\set stemLeftBeamCount = #2
\set stemRightBeamCount = #2
 \note-mod "6" a16-\tweak #'X-offset #0.6 _. ]
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "2" d'8]
| %{ bar 18: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "3" e'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "6" a'8]
 \note-mod "5" g'4 | %{ bar 19: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "5" g8-\tweak #'X-offset #0.6 _. [
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #2
 \note-mod "5" g16-\tweak #'X-offset #0.6 _. 
( \set stemLeftBeamCount = #2
\set stemRightBeamCount = #2
 \note-mod "6" a16-\tweak #'X-offset #0.6 _. ]
) \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "3" e'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "2" d'8]
| %{ bar 20: %}
 \note-mod "2" d'4
(  \note-mod "1" c'4 ) ( | %{ bar 21: %}
< \note-mod "5" g'  \tweak #'Y-offset #2.0 \note-mod "1" c'' \tweak #'Y-offset #3.6 ^. \tweak #'Y-offset #5.0 \note-mod "3" e'' \tweak #'Y-offset #6.6 ^. >4
) \arpeggio  \note-mod "–" c'4 \break | %{ bar 22: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" r8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #2
 \note-mod "3" e'16
\set stemLeftBeamCount = #2
\set stemRightBeamCount = #2
 \note-mod "2" d'16]
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "3" e'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "5" g'8]
| %{ bar 23: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #2
 \note-mod "2" d'16
( \set stemLeftBeamCount = #2
\set stemRightBeamCount = #2
 \note-mod "1" c'16]
)  \note-mod "1" c'4 | %{ bar 24: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "6" a8.-\tweak #'X-offset #0.6 _. [
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #2
 \note-mod "3" e'16]
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #2
 \note-mod "2" d'16[
( \set stemLeftBeamCount = #2
\set stemRightBeamCount = #2
 \note-mod "3" e'16
) \set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "6" a8-\tweak #'X-offset #0.6 _. ]
| %{ bar 25: %}
 \note-mod "5" g4-\tweak #'Y-offset #-1.2 -\tweak #'X-offset #0.6 _. 
 \note-mod "–" g4 | %{ bar 26: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" r8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #2
 \note-mod "1" c'16
\set stemLeftBeamCount = #2
\set stemRightBeamCount = #2
 \note-mod "6" a16-\tweak #'X-offset #0.6 _. ]
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "2" d'8]
| %{ bar 27: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "3" e'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #2
 \note-mod "6" a'16
( \set stemLeftBeamCount = #2
\set stemRightBeamCount = #2
 \note-mod "1" c''16^.]
) \set stemLeftBeamCount = #0
\set stemRightBeamCount = #2
 \note-mod "6" a'16[
( \set stemLeftBeamCount = #2
\set stemRightBeamCount = #2
 \note-mod "5" g'16
) \set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "3" e'8]
| %{ bar 28: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #2
 \note-mod "6" a16-\tweak #'X-offset #0.6 _. 
( \set stemLeftBeamCount = #2
\set stemRightBeamCount = #2
 \note-mod "1" c'16]
) \set stemLeftBeamCount = #0
\set stemRightBeamCount = #2
 \note-mod "5" g'16[
( \set stemLeftBeamCount = #2
\set stemRightBeamCount = #2
 \note-mod "6" a'16
) \set stemLeftBeamCount = #2
\set stemRightBeamCount = #2
 \note-mod "4" f'16
( \set stemLeftBeamCount = #2
\set stemRightBeamCount = #2
 \note-mod "3" e'16]
) | %{ bar 29: %}
 \note-mod "2" d'4
 \note-mod "–" d'4 \break | %{ bar 30: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" r8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #2
 \note-mod "3" e'16
\set stemLeftBeamCount = #2
\set stemRightBeamCount = #2
 \note-mod "2" d'16]
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "3" e'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "6" a'8]
| %{ bar 31: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #2
 \note-mod "5" g'16[
( \set stemLeftBeamCount = #2
\set stemRightBeamCount = #2
 \note-mod "6" a'16
) \set stemLeftBeamCount = #2
\set stemRightBeamCount = #2
 \note-mod "3" e'16
( \set stemLeftBeamCount = #2
\set stemRightBeamCount = #2
 \note-mod "2" d'16]
) \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "3" e'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "5" g'8]
| %{ bar 32: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8.[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #2
 \note-mod "3" e'16]
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #2
 \note-mod "2" d'16[
( \set stemLeftBeamCount = #2
\set stemRightBeamCount = #2
 \note-mod "3" e'16
) \set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "5" g8-\tweak #'X-offset #0.6 _. ]
| %{ bar 33: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
]  (  \note-mod "6" a4.-\tweak #'Y-offset #-1.2 -\tweak #'X-offset #0.6 _. 
) | %{ bar 34: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" r8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #2
 \note-mod "1" c'16
\set stemLeftBeamCount = #2
\set stemRightBeamCount = #2
 \note-mod "6" a16-\tweak #'X-offset #0.6 _. ]
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "2" d'8]
| %{ bar 35: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "3" e'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #2
 \note-mod "2" d'16
( \set stemLeftBeamCount = #2
\set stemRightBeamCount = #2
 \note-mod "3" e'16]
) \set stemLeftBeamCount = #0
\set stemRightBeamCount = #2
 \note-mod "2" d'16[
( \set stemLeftBeamCount = #2
\set stemRightBeamCount = #2
 \note-mod "3" e'16
) \set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "5" g'8]
| %{ bar 36: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8.[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #2
 \note-mod "3" e'16]
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "3" e'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "2" d'8]
| %{ bar 37: %}
 \note-mod "2" d'4
(  \note-mod "1" c'4 ) ~ | %{ bar 38: %}
 \note-mod "1" c'4
 \note-mod "–" c'4 \break | %{ bar 39: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "3" e'8[
^"右手八度音" \set stemLeftBeamCount = #1
\set stemRightBeamCount = #2
 \note-mod "5" g'16
\set stemLeftBeamCount = #2
\set stemRightBeamCount = #2
 \note-mod "6" a'16]
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #2
 \note-mod "1" c''16^.[
( \set stemLeftBeamCount = #2
\set stemRightBeamCount = #2
 \note-mod "2" d''16^.
) \set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "7" b'8]
| %{ bar 40: %}
 \note-mod "6" a'4
 \note-mod "–" a'4 | %{ bar 41: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "6" a'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #2
 \note-mod "2" d''16^.
\set stemLeftBeamCount = #2
\set stemRightBeamCount = #2
 \note-mod "3" e''16^.]
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #2
 \note-mod "1" c''16^.[
( \set stemLeftBeamCount = #2
\set stemRightBeamCount = #2
 \note-mod "2" d''16^.
) \set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "6" a'8]
| %{ bar 42: %}
 \note-mod "5" g'4
 \note-mod "–" g'4 | %{ bar 43: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "6" a'8[
^"右手高八度" \set stemLeftBeamCount = #1
\set stemRightBeamCount = #2
 \note-mod "5" g'16
\set stemLeftBeamCount = #2
\set stemRightBeamCount = #2
 \note-mod "6" a'16]
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c''8^.[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #2
 \note-mod "1" c''16^.
\set stemLeftBeamCount = #2
\set stemRightBeamCount = #2
 \note-mod "1" c''16^.]
| %{ bar 44: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "5" g'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #2
 \note-mod "6" a'16
( \set stemLeftBeamCount = #2
\set stemRightBeamCount = #2
 \note-mod "1" c''16^.]
) \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "5" g'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "3" e'8]
| %{ bar 45: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "5" g'8.[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #2
 \note-mod "6" a'16]
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c''8^.[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #2
 \note-mod "6" a'16
( \set stemLeftBeamCount = #2
\set stemRightBeamCount = #2
 \note-mod "5" g'16]
) | %{ bar 46: %}
 \note-mod "2" d''4^.
 \note-mod "–" d''4 \break | %{ bar 47: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "3" e'8[
^"右手八度音" \set stemLeftBeamCount = #1
\set stemRightBeamCount = #2
 \note-mod "5" g'16
\set stemLeftBeamCount = #2
\set stemRightBeamCount = #2
 \note-mod "6" a'16]
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #2
 \note-mod "1" c''16^.[
( \set stemLeftBeamCount = #2
\set stemRightBeamCount = #2
 \note-mod "2" d''16^.
) \set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "7" b'8]
| %{ bar 48: %}
 \note-mod "6" a'4
 \note-mod "–" a'4 | %{ bar 49: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "6" a'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #2
 \note-mod "2" d''16^.
\set stemLeftBeamCount = #2
\set stemRightBeamCount = #2
 \note-mod "3" e''16^.]
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #2
 \note-mod "1" c''16^.[
( \set stemLeftBeamCount = #2
\set stemRightBeamCount = #2
 \note-mod "2" d''16^.
) \set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "6" a'8]
| %{ bar 50: %}
 \note-mod "5" g'4
 \note-mod "–" g'4 | %{ bar 51: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "6" a'8[
^"右手高八度" \set stemLeftBeamCount = #1
\set stemRightBeamCount = #2
 \note-mod "5" g'16
\set stemLeftBeamCount = #2
\set stemRightBeamCount = #2
 \note-mod "6" a'16]
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c''8^.[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #2
 \note-mod "1" c''16^.
\set stemLeftBeamCount = #2
\set stemRightBeamCount = #2
 \note-mod "1" c''16^.]
| %{ bar 52: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #2
 \note-mod "5" g'16[
( \set stemLeftBeamCount = #2
\set stemRightBeamCount = #2
 \note-mod "6" a'16
) \set stemLeftBeamCount = #2
\set stemRightBeamCount = #2
 \note-mod "3" e'16
( \set stemLeftBeamCount = #2
\set stemRightBeamCount = #2
 \note-mod "2" d'16]
)  \note-mod "3" e'4 | %{ bar 53: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "5" g'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #2
 \note-mod "6" a'16
\set stemLeftBeamCount = #2
\set stemRightBeamCount = #2
 \note-mod "1" c''16^.]
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "7" b'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "6" a'8]
| %{ bar 54: %}
 \note-mod "1" c''4^.
\=JianpuTie(  \note-mod "–" c''4 | %{ bar 55: %}
 \note-mod "1" c''4^.
\=JianpuTie)  \note-mod "–" c''4 \break | %{ bar 56: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "6" a'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #2
 \note-mod "5" g'16
\set stemLeftBeamCount = #2
\set stemRightBeamCount = #2
 \note-mod "6" a'16]
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c''8^.[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #2
 \note-mod "1" c''16^.
\set stemLeftBeamCount = #2
\set stemRightBeamCount = #2
 \note-mod "1" c''16^.]
| %{ bar 57: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #2
 \note-mod "5" g'16[
( \set stemLeftBeamCount = #2
\set stemRightBeamCount = #2
 \note-mod "6" a'16
) \set stemLeftBeamCount = #2
\set stemRightBeamCount = #2
 \note-mod "3" e'16
( \set stemLeftBeamCount = #2
\set stemRightBeamCount = #2
 \note-mod "2" d'16]
)  \note-mod "3" e'4 | %{ bar 58: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "5" g'8[
^"右手八度音" \set stemLeftBeamCount = #1
\set stemRightBeamCount = #2
 \note-mod "6" a'16
\set stemLeftBeamCount = #2
\set stemRightBeamCount = #2
 \note-mod "1" c''16^.]
\grace { \jianpuGraceCurveStart s16 [ \jianpuGraceCurveEnd \set stemLeftBeamCount = #0
\set stemRightBeamCount = #2
 \note-mod "2" d''16^.] }
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "3" e''8^.[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "6" a'8]
| %{ bar 59: %}
 \note-mod "1" c''4^.
\=JianpuTie(  \note-mod "–" c''4 | %{ bar 60: %}
 \note-mod "1" c''4^. \=JianpuTie)
 \note-mod "–" c''4 | \bar "|." } }
% === END JIANPU STAFF ===

\new Lyrics = "If" { \lyricsto "e" { \override LyricText.self-alignment-X = #LEFT \skip1 \skip1 \skip1 \skip1 \skip1 \skip1 \skip1 \skip1 \skip1 \skip1 \skip1 \skip1 \skip1 \skip1 \skip1 \skip1 \skip1 \skip1 \skip1 \skip1 山 水 流 过 丹 青 醉  谁 对 月 举 杯 \skip1  玉 笔 多 情 一 幕  砂 红 四 大 家 人 美 \skip1   墨 香 描 来 江 南 雨  琴 声 在 等 谁  满 纸 云 烟 染 峰 秀  仙 鹤 画 中 飞 \skip1   粉 彩 蘸 来 一 片 暖  牡 丹 万 花 开 \skip1  羊 毫 勾 来 梅 兰 竹 菊  君 子 心 中 爱 \skip1   梦 中 又 画 伞 下 情 人  相 亲 和 相 爱  醒 来 再 画 春 夏 秋 冬  家 乡 的 等 待 \skip1  画 一 幅 中 国 画 \skip1  画 一 幅 中 国 美 \skip1  画 不 尽 中 国 的 山 山 水 水  看 也 能 看 醉 \skip1  画 一 幅 中 国 画 \skip1  画 一 幅 中 国 美 \skip1  画 不 尽 浓 浓 的 中 国 情  浓 浓 的 中 国 味 \skip1   画 不 尽 浓 浓 的 中 国 情  浓 浓 的 中 国 味 } } 

%% === BEGIN JIANPU STAFF ===
    \new RhythmicStaff \with {
    \consists "Accidental_engraver" 
    % Get rid of the stave but not the barlines:
    \override StaffSymbol.line-count = #0 % tested in 2.15.40, 2.16.2, 2.18.0, 2.18.2, 2.20.0 and 2.22.2
    \override BarLine.bar-extent = #'(-2 . 2) % LilyPond 2.18: please make barlines as high as the time signature even though we're on a RhythmicStaff (2.16 and 2.15 don't need this although its presence doesn't hurt; Issue 3685 seems to indicate they'll fix it post-2.18)
    $(add-grace-property 'Voice 'Stem 'direction DOWN)
    $(add-grace-property 'Voice 'Slur 'direction UP)
    $(add-grace-property 'Voice 'Stem 'length-fraction 0.5)
    $(add-grace-property 'Voice 'Beam 'beam-thickness 0.1)
    $(add-grace-property 'Voice 'Beam 'length-fraction 0.3)
    $(add-grace-property 'Voice 'Beam 'after-line-breaking flip-beams)
    $(add-grace-property 'Voice 'Beam 'Y-offset 2.5)
    $(add-grace-property 'Voice 'NoteHead 'Y-offset 2.5)
    }
    { \new Voice="XY" {
    \override Beam.transparent = ##f
    \override Stem.direction = #DOWN
    \override Tie.staff-position = #2.5
    \tupletUp
    \tieUp
    \override Stem.length-fraction = #0.5
    \override Beam.beam-thickness = #0.1
    \override Beam.length-fraction = #0.5
    \override Beam.after-line-breaking = #flip-beams
    \override Voice.Rest.style = #'neomensural % this size tends to line up better (we'll override the appearance anyway)
    \override Accidental.font-size = #-4
    \override TupletBracket.bracket-visibility = ##t
\set Voice.chordChanges = ##t %% 2.19 bug workaround

    \override Staff.TimeSignature.style = #'numbered
    \override Staff.Stem.transparent = ##t
     < \note-mod "6" a'  \tweak #'Y-offset #2.0 \note-mod "1" c'  \tweak #'Y-offset #4.0 \note-mod "3" e'  >4-\tweak #'Y-offset #-1.2 -\tweak #'X-offset #0.6 _. 
\arpeggio  \note-mod "–" c4 < \note-mod "5" g'  \tweak #'Y-offset #2.0 \note-mod "1" c'  \tweak #'Y-offset #4.0 \note-mod "3" e'  >4-\tweak #'Y-offset #-1.2 -\tweak #'X-offset #0.6 _. 
\arpeggio  \note-mod "–" c4 | %{ bar 2: %}
 \note-mod "5" g4-\tweak #'Y-offset #-1.2 -\tweak #'X-offset #0.6 _. 
 \note-mod "5" g,4-\tweak #'Y-offset #-2 -\tweak #'X-offset #0.6 _\two-dots 
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #2
 \note-mod "1" c16-\tweak #'X-offset #0.6 _. [
\set stemLeftBeamCount = #2
\set stemRightBeamCount = #2
 \note-mod "5" g16-\tweak #'X-offset #0.6 _. 
\set stemLeftBeamCount = #2
\set stemRightBeamCount = #2
 \note-mod "6" a16-\tweak #'X-offset #0.6 _. 
\set stemLeftBeamCount = #2
\set stemRightBeamCount = #2
 \note-mod "5" g16-\tweak #'X-offset #0.6 _. ]
 \note-mod "1" c'4 \break | %{ bar 3: %}
 \note-mod "1" c'4
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "5" g'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "3" e'8]
 \note-mod "6" a4-\tweak #'Y-offset #-1.2 -\tweak #'X-offset #0.6 _. 
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "3" e'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "1" c'8]
| %{ bar 4: %}
 \note-mod "4" f4-\tweak #'Y-offset #-1.2 -\tweak #'X-offset #0.6 _. 
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "6" a8-\tweak #'X-offset #0.6 _. ]
 \note-mod "5" g4-\tweak #'Y-offset #-1.2 -\tweak #'X-offset #0.6 _. 
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "5" g'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "2" d'8]
| %{ bar 5: %}
< \note-mod "6" a'  \tweak #'Y-offset #2.0 \note-mod "1" c'  \tweak #'Y-offset #4.0 \note-mod "3" e'  >4-\tweak #'Y-offset #-1.2 -\tweak #'X-offset #0.6 _. 
\arpeggio  \note-mod "–" c4 < \note-mod "4" f'  \tweak #'Y-offset #2.0 \note-mod "1" c'  >4-\tweak #'Y-offset #-1.2 -\tweak #'X-offset #0.6 _. 
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #2
 \note-mod "6" a'16[
\set stemLeftBeamCount = #2
\set stemRightBeamCount = #2
 \note-mod "5" g'16
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "3" e'8]
| %{ bar 6: %}
< \note-mod "2" d'  \tweak #'Y-offset #3.0 \note-mod "6" a \tweak #'Y-offset #1.7 -\tweak #'X-offset #0.6 _.  \tweak #'Y-offset #5.0 \note-mod "1" c'  >4-\tweak #'Y-offset #-1.2 -\tweak #'X-offset #0.6 _. 
\arpeggio  \note-mod "–" c4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #2
 \note-mod "5" g'16[
\set stemLeftBeamCount = #2
\set stemRightBeamCount = #2
 \note-mod "2" d'16
\set stemLeftBeamCount = #2
\set stemRightBeamCount = #2
 \note-mod "1" c'16
\set stemLeftBeamCount = #2
\set stemRightBeamCount = #2
 \note-mod "6" a16-\tweak #'X-offset #0.6 _. ]
 \note-mod "5" g4-\tweak #'Y-offset #-1.2 -\tweak #'X-offset #0.6 _. 
\break | %{ bar 7: %}
< \note-mod "5" g'  \tweak #'Y-offset #2.0 \note-mod "1" c'  \tweak #'Y-offset #4.0 \note-mod "3" e'  >4-\tweak #'Y-offset #-1.2 -\tweak #'X-offset #0.6 _. 
 \note-mod "–" c4 < \note-mod "5" g'  \tweak #'Y-offset #3.0 \note-mod "7" b \tweak #'Y-offset #1.7 -\tweak #'X-offset #0.6 _.  \tweak #'Y-offset #5.0 \note-mod "3" e'  >4-\tweak #'Y-offset #-1.2 -\tweak #'X-offset #0.6 _. 
\arpeggio  \note-mod "–" c4 | %{ bar 8: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8.[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #2
 \note-mod "3" e'16]
 \note-mod "5" g4-\tweak #'Y-offset #-1.2 -\tweak #'X-offset #0.6 _. 
< \note-mod "6" a'  \tweak #'Y-offset #2.0 \note-mod "1" c'  \tweak #'Y-offset #4.0 \note-mod "3" e'  >4.-\tweak #'Y-offset #-1.2 -\tweak #'X-offset #0.6 _. 
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
< \note-mod "6" a'  \tweak #'Y-offset #2.0 \note-mod "1" c'  \tweak #'Y-offset #4.0 \note-mod "3" e'  >8-\tweak #'X-offset #0.6 _. []
| %{ bar 9: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "4" f8-\tweak #'X-offset #0.6 _. [
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "1" c'8]
 \note-mod "4" f'4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "3" e8-\tweak #'X-offset #0.6 _. [
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "1" c'8]
 \note-mod "3" e'4 | %{ bar 10: %}
 \note-mod "2" d4-\tweak #'Y-offset #-1.2 -\tweak #'X-offset #0.6 _. 
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "5" g8-\tweak #'X-offset #0.6 _. [
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "5" g,8-\tweak #'X-offset #0.6 _\two-dots ]
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c8-\tweak #'X-offset #0.6 _. [
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #2
 \note-mod "5" g16-\tweak #'X-offset #0.6 _. 
\set stemLeftBeamCount = #2
\set stemRightBeamCount = #2
 \note-mod "6" a16-\tweak #'X-offset #0.6 _. ]
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "2" d'8]
| %{ bar 11: %}
 \note-mod "3" e'4
 \note-mod "–" e'4 \break \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #2
 \note-mod "5" g'16
\set stemLeftBeamCount = #2
\set stemRightBeamCount = #2
 \note-mod "6" a'16]
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "5" g'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "3" e'8]
| %{ bar 12: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "6" a8-\tweak #'X-offset #0.6 _. [
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #2
 \note-mod "3" e'16
\set stemLeftBeamCount = #2
\set stemRightBeamCount = #2
 \note-mod "2" d'16]
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "3" e'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "1" c'8]
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "4" f8-\tweak #'X-offset #0.6 _. [
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #2
 \note-mod "3" e'16
\set stemLeftBeamCount = #2
\set stemRightBeamCount = #2
 \note-mod "2" d'16]
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "3" e'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "1" c'8]
| %{ bar 13: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "5" g8-\tweak #'X-offset #0.6 _. [
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #2
 \note-mod "1" c'16
\set stemLeftBeamCount = #2
\set stemRightBeamCount = #2
 \note-mod "2" d'16]
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "5" g'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "5" g8-\tweak #'X-offset #0.6 _. ]
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "6" a8-\tweak #'X-offset #0.6 _. [
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "1" c'8]
 \note-mod "3" e'4 | %{ bar 14: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" r8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "1" c''8^.]
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "6" a'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "5" g'8]
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "6" a8-\tweak #'X-offset #0.6 _. ]
 \note-mod "2" d4-\tweak #'Y-offset #-1.2 -\tweak #'X-offset #0.6 _. 
| %{ bar 15: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #2
 \note-mod "5" g,16-\tweak #'X-offset #0.6 _\two-dots [
\set stemLeftBeamCount = #2
\set stemRightBeamCount = #2
 \note-mod "5" g16-\tweak #'X-offset #0.6 _. 
\set stemLeftBeamCount = #2
\set stemRightBeamCount = #2
 \note-mod "6" a16-\tweak #'X-offset #0.6 _. 
\set stemLeftBeamCount = #2
\set stemRightBeamCount = #2
 \note-mod "1" c'16]
 \note-mod "5" g'4 \break < \note-mod "5" g'  \tweak #'Y-offset #2.0 \note-mod "1" c'  \tweak #'Y-offset #4.0 \note-mod "3" e'  >4-\tweak #'Y-offset #-1.2 -\tweak #'X-offset #0.6 _. 
 \note-mod "–" c4 | %{ bar 16: %}
< \note-mod "5" g'  \tweak #'Y-offset #3.0 \note-mod "7" b \tweak #'Y-offset #1.7 -\tweak #'X-offset #0.6 _.  \tweak #'Y-offset #5.0 \note-mod "3" e'  >4-\tweak #'Y-offset #-1.2 -\tweak #'X-offset #0.6 _. 
\arpeggio  \note-mod "–" c4 \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8.[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #2
 \note-mod "3" e'16]
 \note-mod "5" g4-\tweak #'Y-offset #-1.2 -\tweak #'X-offset #0.6 _. 
| %{ bar 17: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "0" r8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #2
 \note-mod "3" e'16
\set stemLeftBeamCount = #2
\set stemRightBeamCount = #2
 \note-mod "2" d'16]
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "1" c'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "6" a8-\tweak #'X-offset #0.6 _. ]
< \note-mod "1" c'  \tweak #'Y-offset #2.0 \note-mod "4" f'  >4-\tweak #'Y-offset #-1.2 -\tweak #'X-offset #0.6 _. 
 \note-mod "–" c4 | %{ bar 18: %}
 \note-mod "1" c4-\tweak #'Y-offset #-1.2 -\tweak #'X-offset #0.6 _. 
< \note-mod "5" g'  \tweak #'Y-offset #2.0 \note-mod "1" c'  >4-\tweak #'Y-offset #-1.2 -\tweak #'X-offset #0.6 _. 
< \note-mod "5" g'  \tweak #'Y-offset #3.0 \note-mod "2" d \tweak #'Y-offset #1.7 -\tweak #'X-offset #0.6 _.  \tweak #'Y-offset #6.0 \note-mod "5" g \tweak #'Y-offset #4.7 -\tweak #'X-offset #0.6 _.  >4-\tweak #'Y-offset #-2 -\tweak #'X-offset #0.6 _\two-dots 
\arpeggio  \note-mod "–" c,4 | %{ bar 19: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #2
 \note-mod "1" c16-\tweak #'X-offset #0.6 _. [
\set stemLeftBeamCount = #2
\set stemRightBeamCount = #2
 \note-mod "5" g16-\tweak #'X-offset #0.6 _. 
\set stemLeftBeamCount = #2
\set stemRightBeamCount = #2
 \note-mod "6" a16-\tweak #'X-offset #0.6 _. 
\set stemLeftBeamCount = #2
\set stemRightBeamCount = #2
 \note-mod "1" c'16]
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
 \note-mod "2" d'8[
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
 \note-mod "3" e'8]
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #2
 \note-mod "5" g'16[
\set stemLeftBeamCount = #2
\set stemRightBeamCount = #2
 \note-mod "6" a'16
^"右手" \set stemLeftBeamCount = #2
\set stemRightBeamCount = #2
 \note-mod "1" c''16^.
\set stemLeftBeamCount = #2
\set stemRightBeamCount = #2
 \note-mod "2" d''16^.]
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #2
 \note-mod "6" a'16[
\set stemLeftBeamCount = #2
\set stemRightBeamCount = #2
 \note-mod "1" c''16^.
^"右手" \set stemLeftBeamCount = #2
\set stemRightBeamCount = #2
 \note-mod "2" d''16^.
\set stemLeftBeamCount = #2
\set stemRightBeamCount = #2
 \note-mod "1" c''16^.]
\break | %{ bar 20: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #2
 \note-mod "1" c,16-\tweak #'X-offset #0.6 _\two-dots [
\set stemLeftBeamCount = #2
\set stemRightBeamCount = #2
 \note-mod "5" g,16-\tweak #'X-offset #0.6 _\two-dots 
\set stemLeftBeamCount = #2
\set stemRightBeamCount = #2
 \note-mod "1" c16-\tweak #'X-offset #0.6 _. 
\set stemLeftBeamCount = #2
\set stemRightBeamCount = #2
 \note-mod "3" e16-\tweak #'X-offset #0.6 _. ]
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #2
 \note-mod "5" g16-\tweak #'X-offset #0.6 _. [
\set stemLeftBeamCount = #2
\set stemRightBeamCount = #2
 \note-mod "3" e16-\tweak #'X-offset #0.6 _. 
\set stemLeftBeamCount = #2
\set stemRightBeamCount = #2
 \note-mod "1" c16-\tweak #'X-offset #0.6 _. 
\set stemLeftBeamCount = #2
\set stemRightBeamCount = #2
 \note-mod "5" g,16-\tweak #'X-offset #0.6 _\two-dots ]
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #2
 \note-mod "4" f,16-\tweak #'X-offset #0.6 _\two-dots [
\set stemLeftBeamCount = #2
\set stemRightBeamCount = #2
 \note-mod "1" c16-\tweak #'X-offset #0.6 _. 
\set stemLeftBeamCount = #2
\set stemRightBeamCount = #2
 \note-mod "4" f16-\tweak #'X-offset #0.6 _. 
\set stemLeftBeamCount = #2
\set stemRightBeamCount = #2
 \note-mod "6" a16-\tweak #'X-offset #0.6 _. ]
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #2
 \note-mod "1" c'16[
\set stemLeftBeamCount = #2
\set stemRightBeamCount = #2
 \note-mod "6" a16-\tweak #'X-offset #0.6 _. 
\set stemLeftBeamCount = #2
\set stemRightBeamCount = #2
 \note-mod "4" f16-\tweak #'X-offset #0.6 _. 
\set stemLeftBeamCount = #2
\set stemRightBeamCount = #2
 \note-mod "1" c16-\tweak #'X-offset #0.6 _. ]
| %{ bar 21: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #2
 \note-mod "2" d,16-\tweak #'X-offset #0.6 _\two-dots [
\set stemLeftBeamCount = #2
\set stemRightBeamCount = #2
 \note-mod "6" a,16-\tweak #'X-offset #0.6 _\two-dots 
\set stemLeftBeamCount = #2
\set stemRightBeamCount = #2
 \note-mod "2" d16-\tweak #'X-offset #0.6 _. 
\set stemLeftBeamCount = #2
\set stemRightBeamCount = #2
 \note-mod "4" fis16-\tweak #'X-offset #0.6 _. ]
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #2
 \note-mod "6" a16-\tweak #'X-offset #0.6 _. [
\set stemLeftBeamCount = #2
\set stemRightBeamCount = #2
 \note-mod "4" fis16-\tweak #'X-offset #0.6 _. 
\set stemLeftBeamCount = #2
\set stemRightBeamCount = #2
 \note-mod "2" d16-\tweak #'X-offset #0.6 _. 
\set stemLeftBeamCount = #2
\set stemRightBeamCount = #2
 \note-mod "6" a,16-\tweak #'X-offset #0.6 _\two-dots ]
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #2
 \note-mod "5" g,16-\tweak #'X-offset #0.6 _\two-dots [
\set stemLeftBeamCount = #2
\set stemRightBeamCount = #2
 \note-mod "5" g16-\tweak #'X-offset #0.6 _. 
\set stemLeftBeamCount = #2
\set stemRightBeamCount = #2
 \note-mod "6" a16-\tweak #'X-offset #0.6 _. 
\set stemLeftBeamCount = #2
\set stemRightBeamCount = #2
 \note-mod "1" c'16]
 \note-mod "5" g'4 | %{ bar 22: %}
 \note-mod "6" a,4-\tweak #'Y-offset #-2 -\tweak #'X-offset #0.6 _\two-dots 
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
< \note-mod "6" a'  \tweak #'Y-offset #2.0 \note-mod "1" c'  \tweak #'Y-offset #4.0 \note-mod "3" e'  >8-\tweak #'X-offset #0.6 _. [
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
< \note-mod "6" a'  \tweak #'Y-offset #2.0 \note-mod "1" c'  \tweak #'Y-offset #4.0 \note-mod "3" e'  >8-\tweak #'X-offset #0.6 _. ]
 \note-mod "1" c,4-\tweak #'Y-offset #-2 -\tweak #'X-offset #0.6 _\two-dots 
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
< \note-mod "5" g'  \tweak #'Y-offset #2.0 \note-mod "1" c'  \tweak #'Y-offset #4.0 \note-mod "3" e'  >8-\tweak #'X-offset #0.6 _. [
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
< \note-mod "5" g'  \tweak #'Y-offset #2.0 \note-mod "1" c'  \tweak #'Y-offset #4.0 \note-mod "3" e'  >8-\tweak #'X-offset #0.6 _. ]
| %{ bar 23: %}
 \note-mod "2" d,4-\tweak #'Y-offset #-2 -\tweak #'X-offset #0.6 _\two-dots 
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
< \note-mod "6" a'  \tweak #'Y-offset #2.0 \note-mod "2" d'  \tweak #'Y-offset #4.0 \note-mod "4" fis'  >8-\tweak #'X-offset #0.6 _. [
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
< \note-mod "6" a'  \tweak #'Y-offset #2.0 \note-mod "2" d'  \tweak #'Y-offset #4.0 \note-mod "4" fis'  >8-\tweak #'X-offset #0.6 _. ]
\times 4/6 { \set stemLeftBeamCount = #0
\set stemRightBeamCount = #2
 \note-mod "5" g,16-\tweak #'X-offset #0.6 _\two-dots [
_"长琶音" \set stemLeftBeamCount = #2
\set stemRightBeamCount = #2
 \note-mod "2" d16-\tweak #'X-offset #0.6 _. 
\set stemLeftBeamCount = #2
\set stemRightBeamCount = #2
 \note-mod "5" g16-\tweak #'X-offset #0.6 _. 
\set stemLeftBeamCount = #2
\set stemRightBeamCount = #2
 \note-mod "7" b16-\tweak #'X-offset #0.6 _. 
\set stemLeftBeamCount = #2
\set stemRightBeamCount = #2
 \note-mod "2" d'16
\set stemLeftBeamCount = #2
\set stemRightBeamCount = #2
 \note-mod "5" g'16]
} \times 4/6 { \set stemLeftBeamCount = #0
\set stemRightBeamCount = #2
 \note-mod "5" g16-\tweak #'X-offset #0.6 _. [
\set stemLeftBeamCount = #2
\set stemRightBeamCount = #2
 \note-mod "2" d'16
\set stemLeftBeamCount = #2
\set stemRightBeamCount = #2
 \note-mod "5" g'16
\set stemLeftBeamCount = #2
\set stemRightBeamCount = #2
 \note-mod "7" b'16
\set stemLeftBeamCount = #2
\set stemRightBeamCount = #2
 \note-mod "2" d''16^.
\set stemLeftBeamCount = #2
\set stemRightBeamCount = #2
 \note-mod "5" g''16^.]
} \break | %{ bar 24: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #2
 \note-mod "1" c,16-\tweak #'X-offset #0.6 _\two-dots [
\set stemLeftBeamCount = #2
\set stemRightBeamCount = #2
 \note-mod "5" g,16-\tweak #'X-offset #0.6 _\two-dots 
\set stemLeftBeamCount = #2
\set stemRightBeamCount = #2
 \note-mod "1" c16-\tweak #'X-offset #0.6 _. 
\set stemLeftBeamCount = #2
\set stemRightBeamCount = #2
 \note-mod "3" e16-\tweak #'X-offset #0.6 _. ]
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #2
 \note-mod "5" g16-\tweak #'X-offset #0.6 _. [
\set stemLeftBeamCount = #2
\set stemRightBeamCount = #2
 \note-mod "3" e16-\tweak #'X-offset #0.6 _. 
\set stemLeftBeamCount = #2
\set stemRightBeamCount = #2
 \note-mod "1" c16-\tweak #'X-offset #0.6 _. 
\set stemLeftBeamCount = #2
\set stemRightBeamCount = #2
 \note-mod "5" g,16-\tweak #'X-offset #0.6 _\two-dots ]
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #2
 \note-mod "4" f,16-\tweak #'X-offset #0.6 _\two-dots [
\set stemLeftBeamCount = #2
\set stemRightBeamCount = #2
 \note-mod "1" c16-\tweak #'X-offset #0.6 _. 
\set stemLeftBeamCount = #2
\set stemRightBeamCount = #2
 \note-mod "4" f16-\tweak #'X-offset #0.6 _. 
\set stemLeftBeamCount = #2
\set stemRightBeamCount = #2
 \note-mod "6" a16-\tweak #'X-offset #0.6 _. ]
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #2
 \note-mod "1" c'16[
\set stemLeftBeamCount = #2
\set stemRightBeamCount = #2
 \note-mod "6" a16-\tweak #'X-offset #0.6 _. 
\set stemLeftBeamCount = #2
\set stemRightBeamCount = #2
 \note-mod "4" f16-\tweak #'X-offset #0.6 _. 
\set stemLeftBeamCount = #2
\set stemRightBeamCount = #2
 \note-mod "1" c16-\tweak #'X-offset #0.6 _. ]
| %{ bar 25: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #2
 \note-mod "2" d,16-\tweak #'X-offset #0.6 _\two-dots [
\set stemLeftBeamCount = #2
\set stemRightBeamCount = #2
 \note-mod "6" a,16-\tweak #'X-offset #0.6 _\two-dots 
\set stemLeftBeamCount = #2
\set stemRightBeamCount = #2
 \note-mod "2" d16-\tweak #'X-offset #0.6 _. 
\set stemLeftBeamCount = #2
\set stemRightBeamCount = #2
 \note-mod "4" fis16-\tweak #'X-offset #0.6 _. ]
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #2
 \note-mod "6" a16-\tweak #'X-offset #0.6 _. [
\set stemLeftBeamCount = #2
\set stemRightBeamCount = #2
 \note-mod "4" fis16-\tweak #'X-offset #0.6 _. 
\set stemLeftBeamCount = #2
\set stemRightBeamCount = #2
 \note-mod "2" d16-\tweak #'X-offset #0.6 _. 
\set stemLeftBeamCount = #2
\set stemRightBeamCount = #2
 \note-mod "6" a,16-\tweak #'X-offset #0.6 _\two-dots ]
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #2
 \note-mod "5" g,16-\tweak #'X-offset #0.6 _\two-dots [
\set stemLeftBeamCount = #2
\set stemRightBeamCount = #2
 \note-mod "5" g16-\tweak #'X-offset #0.6 _. 
\set stemLeftBeamCount = #2
\set stemRightBeamCount = #2
 \note-mod "6" a16-\tweak #'X-offset #0.6 _. 
\set stemLeftBeamCount = #2
\set stemRightBeamCount = #2
 \note-mod "1" c'16]
 \note-mod "5" g'4 | %{ bar 26: %}
 \note-mod "6" a,4-\tweak #'Y-offset #-2 -\tweak #'X-offset #0.6 _\two-dots 
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #1
< \note-mod "6" a'  \tweak #'Y-offset #2.0 \note-mod "1" c'  \tweak #'Y-offset #4.0 \note-mod "3" e'  >8-\tweak #'X-offset #0.6 _. [
\set stemLeftBeamCount = #1
\set stemRightBeamCount = #1
< \note-mod "6" a'  \tweak #'Y-offset #2.0 \note-mod "1" c'  \tweak #'Y-offset #4.0 \note-mod "3" e'  >8-\tweak #'X-offset #0.6 _. ]
 \note-mod "1" c,4-\tweak #'Y-offset #-2 -\tweak #'X-offset #0.6 _\two-dots 
< \note-mod "5" g'  \tweak #'Y-offset #2.0 \note-mod "1" c'  \tweak #'Y-offset #4.0 \note-mod "3" e'  >4-\tweak #'Y-offset #-1.2 -\tweak #'X-offset #0.6 _. 
| %{ bar 27: %}
< \note-mod "5" g'  \tweak #'Y-offset #3.0 \note-mod "5" g \tweak #'Y-offset #1.7 -\tweak #'X-offset #0.6 _.  >4-\tweak #'Y-offset #-2 -\tweak #'X-offset #0.6 _\two-dots 
< \note-mod "5" g'  \tweak #'Y-offset #3.6 \note-mod "5" g, \tweak #'Y-offset #1.6 -\tweak #'X-offset #0.6 _\two-dots  >4-\tweak #'Y-offset #-2.7 -\tweak #'X-offset #0.6 _\three-dots 
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #2
 \note-mod "1" c16-\tweak #'X-offset #0.6 _. [
\set stemLeftBeamCount = #2
\set stemRightBeamCount = #2
 \note-mod "5" g16-\tweak #'X-offset #0.6 _. 
\set stemLeftBeamCount = #2
\set stemRightBeamCount = #2
 \note-mod "6" a16-\tweak #'X-offset #0.6 _. 
\set stemLeftBeamCount = #2
\set stemRightBeamCount = #2
 \note-mod "1" c'16]
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #2
 \note-mod "2" d'16[
\set stemLeftBeamCount = #2
\set stemRightBeamCount = #2
 \note-mod "3" e'16
\set stemLeftBeamCount = #2
\set stemRightBeamCount = #2
 \note-mod "5" g'16
\set stemLeftBeamCount = #2
\set stemRightBeamCount = #2
 \note-mod "6" a'16]
| %{ bar 28: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #2
 \note-mod "1" c''16^.[
\set stemLeftBeamCount = #2
\set stemRightBeamCount = #2
 \note-mod "6" a'16
\set stemLeftBeamCount = #2
\set stemRightBeamCount = #2
 \note-mod "5" g'16
\set stemLeftBeamCount = #2
\set stemRightBeamCount = #2
 \note-mod "3" e'16]
\set stemLeftBeamCount = #0
\set stemRightBeamCount = #2
 \note-mod "2" d'16[
\set stemLeftBeamCount = #2
\set stemRightBeamCount = #2
 \note-mod "1" c'16
\set stemLeftBeamCount = #2
\set stemRightBeamCount = #2
 \note-mod "6" a16-\tweak #'X-offset #0.6 _. 
\set stemLeftBeamCount = #2
\set stemRightBeamCount = #2
 \note-mod "5" g16-\tweak #'X-offset #0.6 _. ]
< \note-mod "6" a'  \tweak #'Y-offset #2.0 \note-mod "1" c'  \tweak #'Y-offset #4.0 \note-mod "3" e'  >4-\tweak #'Y-offset #-1.2 -\tweak #'X-offset #0.6 _. 
 \note-mod "–" c4 | %{ bar 29: %}
< \note-mod "5" g'  \tweak #'Y-offset #2.0 \note-mod "1" c'  \tweak #'Y-offset #4.0 \note-mod "3" e'  >4-\tweak #'Y-offset #-1.2 -\tweak #'X-offset #0.6 _. 
 \note-mod "–" c4 < \note-mod "5" g'  \tweak #'Y-offset #3.6 \note-mod "5" g, \tweak #'Y-offset #1.6 -\tweak #'X-offset #0.6 _\two-dots  >4-\tweak #'Y-offset #-2.7 -\tweak #'X-offset #0.6 _\three-dots 
< \note-mod "5" g'  \tweak #'Y-offset #3.0 \note-mod "7" b \tweak #'Y-offset #1.7 -\tweak #'X-offset #0.6 _.  \tweak #'Y-offset #5.0 \note-mod "4" f'  >4-\tweak #'Y-offset #-1.2 -\tweak #'X-offset #0.6 _. 
\arpeggio \times 4/6 { | %{ bar 30: %} \set stemLeftBeamCount = #0
\set stemRightBeamCount = #2
 \note-mod "1" c,16-\tweak #'X-offset #0.6 _\two-dots [
_"长琶音四组" \set stemLeftBeamCount = #2
\set stemRightBeamCount = #2
 \note-mod "5" g,16-\tweak #'X-offset #0.6 _\two-dots 
\set stemLeftBeamCount = #2
\set stemRightBeamCount = #2
 \note-mod "1" c16-\tweak #'X-offset #0.6 _. 
\set stemLeftBeamCount = #2
\set stemRightBeamCount = #2
 \note-mod "3" e16-\tweak #'X-offset #0.6 _. 
\set stemLeftBeamCount = #2
\set stemRightBeamCount = #2
 \note-mod "5" g16-\tweak #'X-offset #0.6 _. 
\set stemLeftBeamCount = #2
\set stemRightBeamCount = #2
 \note-mod "1" c'16]
} \times 4/6 { \set stemLeftBeamCount = #0
\set stemRightBeamCount = #2
 \note-mod "1" c16-\tweak #'X-offset #0.6 _. [
\set stemLeftBeamCount = #2
\set stemRightBeamCount = #2
 \note-mod "5" g16-\tweak #'X-offset #0.6 _. 
\set stemLeftBeamCount = #2
\set stemRightBeamCount = #2
 \note-mod "1" c'16
\set stemLeftBeamCount = #2
\set stemRightBeamCount = #2
 \note-mod "3" e'16
\set stemLeftBeamCount = #2
\set stemRightBeamCount = #2
 \note-mod "5" g'16
\set stemLeftBeamCount = #2
\set stemRightBeamCount = #2
 \note-mod "1" c''16^.]
} \times 4/6 { \set stemLeftBeamCount = #0
\set stemRightBeamCount = #2
 \note-mod "1" c'16[
\set stemLeftBeamCount = #2
\set stemRightBeamCount = #2
 \note-mod "5" g'16
\set stemLeftBeamCount = #2
\set stemRightBeamCount = #2
 \note-mod "1" c''16^.
\set stemLeftBeamCount = #2
\set stemRightBeamCount = #2
 \note-mod "3" e''16^.
\set stemLeftBeamCount = #2
\set stemRightBeamCount = #2
 \note-mod "5" g''16^.
\set stemLeftBeamCount = #2
\set stemRightBeamCount = #2
  \once \override Score.TextScript.outside-staff-priority = 45 \note-mod "1" c'''16-\tweak #'X-offset #0.6 ^\two-dots ]
} \times 4/6 { \set stemLeftBeamCount = #0
\set stemRightBeamCount = #2
 \note-mod "1" c''16^.[
\set stemLeftBeamCount = #2
\set stemRightBeamCount = #2
 \note-mod "5" g''16^.
\set stemLeftBeamCount = #2
\set stemRightBeamCount = #2
  \once \override Score.TextScript.outside-staff-priority = 45 \note-mod "1" c'''16-\tweak #'X-offset #0.6 ^\two-dots 
\set stemLeftBeamCount = #2
\set stemRightBeamCount = #2
  \once \override Score.TextScript.outside-staff-priority = 45 \note-mod "3" e'''16-\tweak #'X-offset #0.6 ^\two-dots 
\set stemLeftBeamCount = #2
\set stemRightBeamCount = #2
  \once \override Score.TextScript.outside-staff-priority = 45 \note-mod "5" g'''16-\tweak #'X-offset #0.6 ^\two-dots 
\set stemLeftBeamCount = #2
\set stemRightBeamCount = #2
 \note-mod "1" c''''16-\tweak #'X-offset #0.6 ^\three-dots ]
} | } }
% === END JIANPU STAFF ===

>>
\header{
title="中国画中国美"
poet="抄谱:ye"
composer="赵真词曲"
arranger="成老师配器"
}
\layout{
  \context {
    \Global
    \grobdescriptions #all-grob-descriptions
  }
  \context {
    \Score
    \consists \jianpuGraceCurveEngraver % for spans
  }
} }
\score {
\unfoldRepeats
<< 
\new ChordNames { \chordmode { a2:m c2 g:m7 c  c2 a2:m f2 g2:m7 a2:m f2 d2:m g2:m7 c2 e2:m d2:m a2:m f2 c2 g2:m7 c1 c2 a2:m f2 g2:m7 a2:m f2 d2:m g2:m7 c2 e2:m d2:m g2:m7 f2 c2 g2:m7 c2 c2 c2 f2 d2 g2:m7 a2:m c2 d2 g2:m7 c2 f2 d2 g2:m7 a2:m c2 g2:m7 c1  a2:m c2 g2:m7 c1 } }

% === BEGIN MIDI STAFF ===
    \new Staff { \new Voice="XZ" { \transpose c c { \key c \major  \time 2/4 \tempo 4=60 a'8 ^"右手高八度" g'16 a'16 c''8 c''16 c''16 | %{ bar 2: %} g'8 c''8 g'8 e'8 | %{ bar 3: %} d'16 e'16 g'16 e'16 d'16 e'16 a16 d'16 | %{ bar 4: %} c'2 \break | %{ bar 5: %} r8 e'16 d'16 e'8 g'8 | %{ bar 6: %} d'8 d'16 ( c'16 ) c'4 | %{ bar 7: %} a8. e'16 d'16 ( e'16 ) a8 | %{ bar 8: %} g2 | %{ bar 9: %} r8 c'16 a16 c'8 d'8 | %{ bar 10: %} e'8 a'16 ( c''16 ) a'16 ( g'16 ) e'8 | %{ bar 11: %} c'8 a16 ( c'16 ) g'16 ( a'16 ) f'16 ( e'16 ) | %{ bar 12: %} d'2 \break | %{ bar 13: %} r8 e'16 d'16 e'8 a'8 | %{ bar 14: %} g'16 ( a'16 ) e'16 ( d'16 ) e'16 ( g'8. ) | %{ bar 15: %} d'8. e'16 g'8 g8 | %{ bar 16: %} c'16 ( d'32 c'32 a4. ) | %{ bar 17: %} r8 c'16 a16 c'8 d'8 | %{ bar 18: %} e'8 a'8 g'4 | %{ bar 19: %} g8 g16 ( a16 ) e'8 d'8 | %{ bar 20: %} d'4 ( c'4 ) ( | %{ bar 21: %} < g' c'' e'' >4  ~ ) \arpeggio < g' c'' e'' >4 \break | %{ bar 22: %} r8 e'16 d'16 e'8 g'8 | %{ bar 23: %} d'8 d'16 ( c'16 ) c'4 | %{ bar 24: %} a8. e'16 d'16 ( e'16 ) a8 | %{ bar 25: %} g2 | %{ bar 26: %} r8 c'16 a16 c'8 d'8 | %{ bar 27: %} e'8 a'16 ( c''16 ) a'16 ( g'16 ) e'8 | %{ bar 28: %} c'8 a16 ( c'16 ) g'16 ( a'16 ) f'16 ( e'16 ) | %{ bar 29: %} d'2 \break | %{ bar 30: %} r8 e'16 d'16 e'8 a'8 | %{ bar 31: %} g'16 ( a'16 ) e'16 ( d'16 ) e'8 g'8 | %{ bar 32: %} d'8. e'16 d'16 ( e'16 ) g8 | %{ bar 33: %} c'8 ( a4. ) | %{ bar 34: %} r8 c'16 a16 c'8 d'8 | %{ bar 35: %} e'8 d'16 ( e'16 ) d'16 ( e'16 ) g'8 | %{ bar 36: %} d'8. e'16 e'8 d'8 | %{ bar 37: %} d'4 ( c'4 ) ~ | %{ bar 38: %} c'2 \break | %{ bar 39: %} e'8 ^"右手八度音" g'16 a'16 c''16 ( d''16 ) b'8 | %{ bar 40: %} a'2 | %{ bar 41: %} a'8 d''16 e''16 c''16 ( d''16 ) a'8 | %{ bar 42: %} g'2 | %{ bar 43: %} a'8 ^"右手高八度" g'16 a'16 c''8 c''16 c''16 | %{ bar 44: %} g'8 a'16 ( c''16 ) g'8 e'8 | %{ bar 45: %} g'8. a'16 c''8 a'16 ( g'16 ) | %{ bar 46: %} d''2 \break | %{ bar 47: %} e'8 ^"右手八度音" g'16 a'16 c''16 ( d''16 ) b'8 | %{ bar 48: %} a'2 | %{ bar 49: %} a'8 d''16 e''16 c''16 ( d''16 ) a'8 | %{ bar 50: %} g'2 | %{ bar 51: %} a'8 ^"右手高八度" g'16 a'16 c''8 c''16 c''16 | %{ bar 52: %} g'16 ( a'16 ) e'16 ( d'16 ) e'4 | %{ bar 53: %} g'8 a'16 c''16 b'8 a'8 | %{ bar 54: %} c''2 ~ | %{ bar 55: %} c''2 \break | %{ bar 56: %} a'8 g'16 a'16 c''8 c''16 c''16 | %{ bar 57: %} g'16 ( a'16 ) e'16 ( d'16 ) e'4 | %{ bar 58: %} g'8 ^"右手八度音" a'16 c''16 \grace { d''16 } e''8 a'8 | %{ bar 59: %} c''2  ~ | %{ bar 60: %} c''2 | } } }
% === END MIDI STAFF ===


% === BEGIN MIDI STAFF ===
    \new Staff { \new Voice="Xa" { < a c' e' >2 \arpeggio < g c' e' >2 \arpeggio | %{ bar 2: %} g4 g,4 c16 g16 a16 g16 c'4 \break | %{ bar 3: %} c'4 g'8 e'8 a4 e'8 c'8 | %{ bar 4: %} f4 c'8 a8 g4 g'8 d'8 | %{ bar 5: %} < a c' e' >2 \arpeggio < f c' >4 a'16 g'16 e'8 | %{ bar 6: %} < d a c' >2 \arpeggio g'16 d'16 c'16 a16 g4 \break | %{ bar 7: %} < g c' e' >2 < g b e' >2 \arpeggio | %{ bar 8: %} d'8. e'16 g4 < a c' e' >4. < a c' e' >8 | %{ bar 9: %} f8 c'8 f'4 e8 c'8 e'4 | %{ bar 10: %} d4 g8 g,8 c8 g16 a16 c'8 d'8 | %{ bar 11: %} e'2 \break c'8 g'16 a'16 g'8 e'8 | %{ bar 12: %} a8 e'16 d'16 e'8 c'8 f8 e'16 d'16 e'8 c'8 | %{ bar 13: %} g8 c'16 d'16 g'8 g8 a8 c'8 e'4 | %{ bar 14: %} r8 c''8 a'8 g'8 d'8 a8 d4 | %{ bar 15: %} g,16 g16 a16 c'16 g'4 \break < g c' e' >2 | %{ bar 16: %} < g b e' >2 \arpeggio d'8. e'16 g4 | %{ bar 17: %} r8 e'16 d'16 c'8 a8 < c f' >2 | %{ bar 18: %} c4 < g c' >4 < g, d g >2 \arpeggio | %{ bar 19: %} c16 g16 a16 c'16 d'8 e'8 g'16 a'16 ^"右手" c''16 d''16 a'16 c''16 ^"右手" d''16 c''16 \break | %{ bar 20: %} c,16 g,16 c16 e16 g16 e16 c16 g,16 f,16 c16 f16 a16 c'16 a16 f16 c16 | %{ bar 21: %} d,16 a,16 d16 fis16 a16 fis16 d16 a,16 g,16 g16 a16 c'16 g'4 | %{ bar 22: %} a,4 < a c' e' >8 < a c' e' >8 c,4 < g c' e' >8 < g c' e' >8 | %{ bar 23: %} d,4 < a d' fis' >8 < a d' fis' >8 \times 4/6 { g,16 _"长琶音" d16 g16 b16 d'16 g'16 } \times 4/6 { g16 d'16 g'16 b'16 d''16 g''16 } \break | %{ bar 24: %} c,16 g,16 c16 e16 g16 e16 c16 g,16 f,16 c16 f16 a16 c'16 a16 f16 c16 | %{ bar 25: %} d,16 a,16 d16 fis16 a16 fis16 d16 a,16 g,16 g16 a16 c'16 g'4 | %{ bar 26: %} a,4 < a c' e' >8 < a c' e' >8 c,4 < g c' e' >4 | %{ bar 27: %} < g, g >4 < g,, g, >4 c16 g16 a16 c'16 d'16 e'16 g'16 a'16 | %{ bar 28: %} c''16 a'16 g'16 e'16 d'16 c'16 a16 g16 < a c' e' >2 | %{ bar 29: %} < g c' e' >2 < g,, g, >4 < g b f' >4 \arpeggio \times 4/6 { | %{ bar 30: %} c,16 _"长琶音四组" g,16 c16 e16 g16 c'16 } \times 4/6 { c16 g16 c'16 e'16 g'16 c''16 } \times 4/6 { c'16 g'16 c''16 e''16 g''16 c'''16 } \times 4/6 { c''16 g''16 c'''16 e'''16 g'''16 c''''16 } | } }
% === END MIDI STAFF ===

>>
\header{
title="中国画中国美"
poet="抄谱:ye"
composer="赵真词曲"
arranger="成老师配器"
}
\midi { \context { \Score tempoWholesPerMinute = #(ly:make-moment 84 4)}} }
