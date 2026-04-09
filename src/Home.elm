module Home exposing (cssStyles, view)

import Html exposing (Html, a, div, h1, h2, p, text)
import Html.Attributes exposing (class, href)
import VirtualDom


view : Html msg
view =
    div [ class "home-content" ]
        [ div [ class "home-eyebrow" ] [ text "// kaitotlex.systems" ]
        , h1 [ class "home-heading" ] [ text "oh hi!" ]
        , div [ class "home-divider" ] []
        , p [ class "home-para" ]
            [ text "I am Warren (or Ren), a student studying electrical engineering and physics." ]
        , p [ class "home-para" ]
            [ text "I'm a student during the day and an electrical engineer and an amateur physicist at night" ]
        , p [ class "home-para" ]
            [ text "I work on projects involving low-power hardware — anything RISC. Currently interested in semiconductor manufacturing, SoCs, RISC-V, and FOSS/FOSH." ]
        , p [ class "home-para" ]
            [ text "I am currently maintaining infra for functor.systems and working in MIT Open-Compute developing hardware, i am also currently building my own RISC-V chip with the vector extension" ]
        , p [ class "home-para" ]
            [ text "I aspire to continue education beyond BS/BA in Physics or Electrical Engineering hopefully contributing to premier research facilities such as the National Aeronautics and Space Administration (NASA) or Organisation européenne pour la recherche nucléaire (CERN)" ]
        , p [ class "home-para" ]
            [ text "I am currently drowning in an information soup" ]
        , div [ class "home-para" ]
            [ p [ class "quote-text" ]
                [ text "\"The clear-cut idea of what is meant by proof ... he perhaps did not possess at all; once he had become satisfied of a theorem's truth, he had scant interest in proving it to others.\"" ]
            , p [ class "quote-attribution" ] [ text "— John Littlewood" ]
            ]
        -- , a [ href ]
        , h2 [] [ text "contact" ]
        , div [ class "contact-links" ]
            [ a [ href "mailto:rlin@kaitotlex.systems", class "contact-item" ] [ text "email (preferred)" ]
            , a [ href "https://matrix.to/#/@kaitotlex26:functor.systems", class "contact-item" ] [ text "matrix" ]
            , a [ href "https://github.com/kaitotlex", class "contact-item" ] [ text "github" ]
            , a [ href "https://bsky.app/profile/kaitotlex.systems", class "contact-item" ] [ text "bluesky" ]
            , a [ href "https://www.instagram.com/kaitotlex.ttv", class "contact-item" ] [ text "instagram" ]
            , a [ href "https://twitter.com/kaitotlex", class "contact-item" ] [ text "twitter / x" ]
            , a [ href "https://osu.ppy.sh/users/26069038", class "contact-item" ] [ text "osu" ]
            , a [ href "https://code.functor.system/kaitotlex", class "contact-item" ] [ text "functor.systems forge" ]
            , a [ href "https://arxiv.org/abs/2204.04549", class "contact-item" ] [ text "send through matter-wave field" ]
            ]

        ]


css : String
css =
    """
    .home-content {
      max-width: 680px;
    }

    .home-eyebrow {
      font-size: 0.72rem;
      color: var(--accent-color);
      letter-spacing: 0.1em;
      margin-bottom: 2rem;
      opacity: 0.8;
    }

    .home-heading {
      font-size: 4rem;
      font-weight: 300;
      color: var(--text-color);
      margin: 0 0 0.25rem;
      letter-spacing: -0.02em;
      line-height: 1.1;
    }

    .home-divider {
      width: 3rem;
      height: 1px;
      background-color: var(--accent-color);
      margin: 2rem 0;
      opacity: 0.6;
    }

    .home-lead {
      font-size: 1rem;
      line-height: 1.8;
      color: var(--text-color);
      margin-bottom: 1.25rem;
      max-width: 580px;
    }

    .home-para {
      font-size: 0.9rem;
      line-height: 1.8;
      color: var(--muted-color);
      margin-bottom: 1rem;
      max-width: 580px;
    }

    @media (max-width: 768px) {
      .home-heading {
        font-size: 2.8rem;
      }
    }
    """


cssStyles : Html msg
cssStyles =
    VirtualDom.node "style" [] [ text css ]
