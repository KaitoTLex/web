module Home exposing (cssStyles, view)

import Html exposing (Html, a, div, h1, h2, img, p, text)
import Html.Attributes exposing (alt, attribute, class, href, src)
import VirtualDom


view : Html msg
view =
    div [ class "home-content" ]
        [ img
            [ src "/assets/DSC_3766.jpg"
            , alt "Shinkansen arriving at a station in Japan"
            , class "home-hero-image"
            , attribute "fetchpriority" "high"
            ]
            []
        , h1 [ class "home-heading" ] [ text "oh hi! I am Ren(林敬宴)" ]
        , div [ class "home-divider" ] []
        , p [ class "home-para" ]
            [ text "I am an undergraduate student at SJSU." ]
        , p [ class "home-para" ]
            [ text "I'm a student during the day and an electrical engineer at night. " ]
        , p [ class "home-para" ]
            [ text "Lately, I've been working on projects relating to Computer Architecture and ASIC design." ]
        , p [ class "home-para" ]
            [ text "I am currently maintaining infra for functor.systems and working in MIT Open-Compute developing hardware, i am also currently building my own RISC-V chip with the vector extension" ]
        , p [ class "home-para" ]
            [ text "I aspire to continue education beyond BS/BA in Physics or Electrical Engineering hopefully contributing to premier research facilities in a lab." ]
        , p [ class "home-para" ]
            [ text "I am currently drowning in an information soup°❀⋆.ೃ࿔*:･°❀⋆.ೃ࿔*:･" ]
        , div [ class "home-para" ]
            [ p [ class "quote-text" ]
                [ text "\"The clear-cut idea of what is meant by proof ... he perhaps did not possess at all; once he had become satisfied of a theorem's truth, he had scant interest in proving it to others.\"" ]
            , p [ class "quote-attribution" ] [ text "— John Littlewood" ]
            ]
        -- , a [ href ]
        , h2 [] [ text "contact" ]
        , div [ class "contact-links" ]
            [ a [ href "mailto:renl@kaitotlex.systems", class "contact-item" ] [ text "email (preferred)" ]
            , a [ href "https://matrix.to/#/@kaitotlex26:functor.systems", class "contact-item" ] [ text "matrix" ]
            , a [ href "https://github.com/kaitotlex", class "contact-item" ] [ text "github" ]
            , a [ href "https://bsky.app/profile/kaitotlex.systems", class "contact-item" ] [ text "bluesky" ]
            , a [ href "https://www.instagram.com/kaitotlex_", class "contact-item" ] [ text "instagram" ]
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
      max-width: 1040px;
    }

    .home-hero-image {
      display: block;
      width: 100%;
      height: clamp(180px, 28vw, 320px);
      object-fit: cover;
      object-position: center;
      border: 1px solid var(--border-color);
      border-radius: 6px;
      margin-bottom: 2rem;
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
