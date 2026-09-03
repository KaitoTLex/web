module About exposing (view)

import Html exposing (Html, div, figcaption, figure, h1, img, p, text)
import Html.Attributes exposing (alt, attribute, class, src)


view : Html msg
view =
    div [ class "about-content" ]
        [ div [ class "about-layout" ]
            [ div [ class "about-copy" ]
                [ h1 [] [ text "more about me..." ]
                , p [ class "about-para" ] [ text "Hello, this site is written in collaboration with Claude Code to ensure that I don't make spelling or grammar mistakes." ]
                , p [ class "about-para" ] [ text "I am currently a freshmen studying Industrial Systems Engineering at San Jose State University ---highlight&link---, I have the intention to study Electrical Engineering here" ]
                , p [ class "about-para" ] [ text "With that time I am able to build this (and a multitude of other things) in a cave, with a scrappy ThinkPad." ]
                , p [ class "about-para" ] [ text "I enjoy being an otaku (watching anime, vtubers, reading manga, listening to vocaloid, etc.), reading, playing video games, wasting time on the world's LAN, and cycling." ]
                , p [ class "about-para" ] [ text "Although I was born in the United States, I have lived most of my life in a suburban mountain/hot-spring area in Beitou, Taipei City. I spent most of my time wasting money in the electronics district and taking the Metro." ]
                , p [ class "about-para" ] [ text "Besides the \"unproductive\" things I enjoy, I hack on electronic devices ranging from deprecated game consoles (like the PS3 or 3DS) to the newest hottest tech (like the Apple M1). I just so happen to be in organizations that require me to roleplay as a smart person among other actually smart people; those organizations being MIT OpenCompute Lab and functor.systems. I also have my own organizations dedicated to doing stupid stuff. I have interest in ASIC design, chip architecture, and aspirations to working at a Fab." ]
                , p [ class "about-para" ] [ text "I don't really do software stuff because it's way too complex and above my knowledge/intuition; however, I just so happen to be on the winning team at HackMIT 2025." ]
                , p [ class "about-para" ] [ text "Because I have to LARP (Live-Action RolePlay) as an intelligent creature, I have found a profound interest, at a high level, in Category Theory, Modal Logic, and Set Theory." ]
                ]
            , figure [ class "about-photo" ]
                [ img
                    [ src "/assets/DSC_4055.jpg"
                    , alt "Black Saab 900 Turbo S driving through Tokyo"
                    , attribute "loading" "lazy"
                    ]
                    []
                , figcaption [] [ text "Featured photo from my trip to Japan in 2026 of a Saab 900 Turbo S." ]
                ]
            ]
        ]
