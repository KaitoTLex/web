module About exposing (view)

import Html exposing (Html, a, div, h1, h2, p, text)
import Html.Attributes exposing (class, href)


view : Html msg
view =
    div [ class "about-content" ]
        [ h1 [] [ text "oh hi!" ]
        , p [ class "about-para" ]
            [ text "i'm a high school student during the day and an electrical engineer and an amateur physicist at night" ]
        , p [ class "about-para" ]
            [ text "i work on projects involving low-power hardware — anything RISC. Interested in semiconductor manufacturing, SoCs, RISC-V, and FOSS/FOSH." ]
        , p [ class "about-para" ]
            [ text "outside of nerd stuff i enjoy: cycling, sim-racing, and badminton. i play piano, bass, and saxophone." ]
        , p [ class "about-para" ]
            [ text "i am an engineer by heart, i've built a couple of impressive projects including a breadboard computer" ]
        , p [ class "about-para" ]
            [ text "i am currently maintaining infra for functor.systems and working in MIT Open-Compute developing hardware, i am also currently building my own RISC-V chip with the vector extension" ]
        , p [ class "about-para" ]
            [ text "i aspire to continue education beyond BS/BA in Physics or Electrical Engineering to contribute to premier research facilities such as the National Aeronautics and Space Administration (NASA) or Organisation européenne pour la recherche nucléaire (CERN)" ]
        , p [ class "about-para" ]
            [ text "i am currently drowning in an information soup" ]
        , div [ class "about-quote" ]
            [ p [ class "quote-text" ]
                [ text "\"The clear-cut idea of what is meant by proof ... he perhaps did not possess at all; once he had become satisfied of a theorem's truth, he had scant interest in proving it to others.\"" ]
            , p [ class "quote-attribution" ] [ text "— John Littlewood" ]
            ]
        , h2 [] [ text "contact" ]
        , div [ class "contact-links" ]
            [ a [ href "mailto:rlin@kaitotlex.systems", class "contact-item" ] [ text "email (pgp preferred)" ]
            , a [ href "https://matrix.to/#/@kaitotlex26:functor.systems", class "contact-item" ] [ text "matrix" ]
            , a [ href "https://github.com/kaitotlex", class "contact-item" ] [ text "github" ]
            , a [ href "https://bsky.app/profile/kaitotlex.systems", class "contact-item" ] [ text "bluesky" ]
            , a [ href "https://www.instagram.com/kaitotlex.ttv", class "contact-item" ] [ text "instagram" ]
            , a [ href "https://twitter.com/kaitotlex", class "contact-item" ] [ text "x / twitter" ]
            , a [ href "https://osu.ppy.sh/users/26069038", class "contact-item" ] [ text "osu" ]
            , a [ href "https://code.functor.system/kaitotlex", class "contact-item" ] [ text "functor.systems code" ]
            , a [ href "https://arxiv.org/abs/2204.04549", class "contact-item" ] [ text "send through matter-wave field" ]
            ]
        ]
