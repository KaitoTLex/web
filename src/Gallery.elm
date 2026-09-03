module Gallery exposing (cssStyles, view)

import Html exposing (Html, a, div, figcaption, figure, h1, img, p, text)
import Html.Attributes exposing (alt, attribute, class, href, src)
import VirtualDom


type alias Photo =
    { file : String
    , alt : String
    , caption : String
    , featured : Bool
    }


photos : List Photo
photos =
    [ { file = "DSC_4055.jpg", alt = "Black Saab 900 Turbo S driving through Tokyo", caption = "Featured photo from my trip to Japan in 2026 of a Saab 900 Turbo S.", featured = True }
    , { file = "DSC_3666.jpg", alt = "Torii gates at Fushimi Inari shrine", caption = "Fushimi Inari, Kyoto", featured = False }
    , { file = "DSC_3689.jpg", alt = "Train arriving at a station in Japan", caption = "Local service", featured = False }
    , { file = "DSC_3745.jpg", alt = "Shinkansen at a station platform", caption = "Departure", featured = False }
    , { file = "DSC_3765.jpg", alt = "Shinkansen arriving at a station", caption = "Arrival", featured = False }
    , { file = "DSC_3766.jpg", alt = "Wide view of a Shinkansen station", caption = "In transit", featured = False }
    , { file = "DSC_4007.jpg", alt = "Crowds and signs in Shibuya at dusk", caption = "Shibuya at dusk", featured = False }
    , { file = "DSC_4056.jpg", alt = "Tokyo buildings silhouetted against the evening sky", caption = "Last light", featured = False }
    , { file = "IMG_8976.jpeg", alt = "Self-portrait pointing toward Tsutenkaku in Osaka", caption = "Tsutenkaku, Osaka", featured = False }
    , { file = "IMG_0119.jpeg", alt = "HackMIT hacker badge held in one hand", caption = "HackMIT 2025", featured = False }
    , { file = "idrewthis.jpg", alt = "Drawing of a blue-haired character working on a laptop", caption = "I drew this", featured = False }
    ]


viewPhoto : Photo -> Html msg
viewPhoto photo =
    figure
        [ class
            (if photo.featured then
                "gallery-item gallery-featured"

             else
                "gallery-item"
            )
        ]
        [ a [ href ("/assets/" ++ photo.file), class "gallery-image-link" ]
            [ img
                [ src ("/assets/" ++ photo.file)
                , alt photo.alt
                , attribute "loading"
                    (if photo.featured then
                        "eager"

                     else
                        "lazy"
                    )
                ]
                []
            ]
        , figcaption []
            [ if photo.featured then
                div [ class "gallery-feature-label" ] [ text "featured / japan 2026" ]

              else
                text ""
            , text photo.caption
            ]
        ]


view : Html msg
view =
    div [ class "gallery-content" ]
        [ h1 [] [ text "gallery" ]
        , p [ class "gallery-intro" ] [ text "Photographs, travels, and assorted artifacts. Select an image to view it full-size." ]
        , div [ class "gallery-grid" ] (List.map viewPhoto photos)
        ]


css : String
css =
    """
    .gallery-content {
      max-width: 1120px;
    }

    .gallery-intro {
      color: var(--muted-color) !important;
      margin-bottom: 2rem !important;
    }

    .gallery-grid {
      display: grid;
      grid-template-columns: repeat(2, minmax(0, 1fr));
      gap: 1.25rem;
      align-items: start;
    }

    .gallery-item {
      margin: 0;
      min-width: 0;
      border: 1px solid var(--border-color);
      border-radius: 6px;
      overflow: hidden;
      background: var(--surface-color);
    }

    .gallery-featured {
      grid-column: span 2;
      display: grid;
      grid-template-columns: minmax(0, 1.65fr) minmax(220px, 0.6fr);
      align-items: stretch;
    }

    .gallery-image-link {
      display: block;
      overflow: hidden;
      background: var(--border-color);
    }

    .gallery-item img {
      display: block;
      width: 100%;
      height: 310px;
      object-fit: cover;
      transition: transform 0.3s ease, opacity 0.3s ease;
    }

    .gallery-featured img {
      height: min(68vh, 660px);
      object-position: center 62%;
    }

    .gallery-image-link:hover img {
      transform: scale(1.012);
      opacity: 0.92;
    }

    .gallery-item figcaption {
      padding: 0.8rem 1rem;
      color: var(--muted-color);
      font-size: 0.76rem;
      line-height: 1.6;
    }

    .gallery-featured figcaption {
      display: flex;
      flex-direction: column;
      justify-content: flex-end;
      padding: 1.5rem;
      color: var(--text-color);
      font-size: 0.88rem;
      border-left: 1px solid var(--border-color);
    }

    .gallery-feature-label {
      color: var(--accent-color);
      font-size: 0.68rem;
      letter-spacing: 0.1em;
      text-transform: uppercase;
      margin-bottom: 0.6rem;
    }

    @media (max-width: 768px) {
      .gallery-grid {
        grid-template-columns: 1fr;
      }

      .gallery-featured {
        grid-column: span 1;
        display: block;
      }

      .gallery-featured img,
      .gallery-item img {
        height: auto;
        max-height: none;
      }

      .gallery-featured figcaption {
        border-left: 0;
        border-top: 1px solid var(--border-color);
      }
    }
    """


cssStyles : Html msg
cssStyles =
    VirtualDom.node "style" [] [ text css ]
