module About exposing (view)

import Html exposing (Html, a, div, h1, h2, p, text)
import Html.Attributes exposing (class, href)


view : Html msg
view =
    div []
        [ h1 [] [ text "oh Hi!" ]
        , p [] [ text "I am Ren or Warren, I am a High School student interested in  Nuclear Theory and Electrical Engineering" ]
        , p [] [ text "I am interested in semi-conductor manufacturing, SOCs, and low power hardware. I work on projects that involves low power hardware -- anything RISC. I can't code. I like FOSS and FOSH, including RISC-V." ]
        , p [] [ text "I like cycling and sim-racing. I watch MLB, NPB, F1, WEC, and WRC as a sport. I play the piano, bass and saxophone (Tenor && Alto). I do RE and hardware hacking in my freetime" ]
        , p [] [ text "I play too much rythm games" ]
        , p [] [ text "If you would like to learn more about me, send a Matrix message or read my logs." ]
        , h2 [] [ text "contact" ]
        , div [ class "contact-links" ]
            [ a [ href "https://web.kaitotlex.systems", class "contact-item" ] [ text "kaitotlex.systems" ]
            , a [ href "mailto:rlin@kaitotlex.systems", class "contact-item" ] [ text "send a email (please sign with pgp)" ]
            , a [ href "https://bsky.app/profile/kaitotlex.systems", class "contact-item" ] [ text "bluesky" ]
            , a [ href "https://twitter.com/Kaito_Malfoy", class "contact-item" ] [ text "X (formerly twitter)" ]
            , a [ href "https://github.com/kaitotlex", class "contact-item" ] [ text "github" ]
            , a [ href "https://osu.ppy.sh/users/26069038", class "contact-item" ] [ text "osu" ]
            , a [ href "https://arxiv.org/abs/2204.04549", class "contact-item" ] [ text "send ripples through the maxwell matter wave" ]
            ]
        ]
