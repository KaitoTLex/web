module About exposing (view)

import Html exposing (Html, a, div, h1, h2, p, text)
import Html.Attributes exposing (class, href)


view : Html msg
view =
    div [ class "about-content" ]
        [ h1 [] [ text "hi, i'm Ren" ]
        , p [ class "about-para" ]
            [ text "I'm a high school student interested in nuclear theory and electrical engineering." ]
        , p [ class "about-para" ]
            [ text "I work on projects involving low-power hardware — anything RISC. Interested in semiconductor manufacturing, SoCs, RISC-V, and FOSS/FOSH." ]
        , p [ class "about-para" ]
            [ text "Outside of that: cycling, sim-racing, MLB, NPB, F1, WEC, WRC. I play piano, bass, and saxophone (tenor & alto). RE and hardware hacking in my free time. Too much rhythm gaming." ]
        , h2 [] [ text "contact" ]
        , div [ class "contact-links" ]
            [ a [ href "mailto:rlin@kaitotlex.systems", class "contact-item" ] [ text "email (pgp preferred)" ]
            , a [ href "https://github.com/kaitotlex", class "contact-item" ] [ text "github" ]
            , a [ href "https://bsky.app/profile/kaitotlex.systems", class "contact-item" ] [ text "bluesky" ]
            , a [ href "https://twitter.com/Kaito_Malfoy", class "contact-item" ] [ text "x / twitter" ]
            , a [ href "https://osu.ppy.sh/users/26069038", class "contact-item" ] [ text "osu" ]
            , a [ href "https://arxiv.org/abs/2204.04549", class "contact-item" ] [ text "arxiv: 2204.04549" ]
            ]
        ]
