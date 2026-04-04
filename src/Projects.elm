module Projects exposing (viewProjects, cssStyles)

import Html exposing (Html, a, div, h1, p, span, text)
import Html.Attributes exposing (class, href, style)
import VirtualDom


viewProjects : Html msg
viewProjects =
    div [ class "projects-container" ]
        [ h1 [ class "projects-header" ] [ text "Projects" ]
        , p [ class "projects-subheader" ] [ text "Open source repositories I've created" ]
        , div [ class "projects-grid" ]
            (List.map viewRepository kaitoRepositories)
        ]


type alias Repository =
    { name : String
    , url : String
    , description : String
    , language : String
    , languageColor : String
    , readmeExcerpt : String
    }


kaitoRepositories : List Repository
kaitoRepositories =
    [ { name = "ame"
      , url = "https://github.com/KaitoTLex/ame"
      , description = " KaitoTLex's functorOS configuration, supported for x86-64-linux and aarch64-linux "
      , language = "Nix"
      , languageColor = "#9e9ab8"
      , readmeExcerpt = "KaitoTLex's EE Optimized FunctorOS (NixOS) configuration, KaitoianOS's spiritual successor"
      }
    ]


viewRepository : Repository -> Html msg
viewRepository repo =
    div [ class "repository-card" ]
        [ div [ class "repository-header" ]
            [ a [ href repo.url, class "repo-title" ] [ text repo.name ]
            , div [ class "repo-meta" ]
                [ span [ class "repo-description" ] [ text repo.description ]
                , div [ class "language-badge" ]
                    [ span [ style "background-color" repo.languageColor, class "language-dot" ] []
                    , span [ class "language-name" ] [ text repo.language ]
                    ]
                ]
            ]
        , div [ class "repository-content" ]
            [ p [] [ text repo.readmeExcerpt ]
            , a [ href (repo.url ++ "/blob/main/README.md"), class "read-more" ] [ text "read more →" ]
            ]
        ]


css : String
css =
    """
    .projects-container {
      max-width: 700px;
    }

    .projects-header {
      font-size: 1.8rem;
      font-weight: 600;
      margin-top: 0;
      margin-bottom: 0.3rem;
    }

    .projects-subheader {
      font-size: 0.88rem;
      color: var(--muted-color);
      margin-bottom: 2rem;
    }

    .projects-grid {
      display: grid;
      grid-template-columns: 1fr;
      gap: 1rem;
    }

    .repository-card {
      background-color: var(--surface-color);
      border: 1px solid var(--border-color);
      border-radius: 6px;
      overflow: hidden;
      transition: border-color 0.2s ease, box-shadow 0.2s ease;
    }

    .repository-card:hover {
      border-color: var(--accent-color);
      box-shadow: 0 2px 16px rgba(0, 0, 0, 0.18);
    }

    .repository-header {
      padding: 1.25rem 1.5rem 1rem;
      border-bottom: 1px solid var(--border-color);
    }

    .repo-title {
      font-size: 0.98rem;
      font-weight: 600;
      color: var(--link-color);
      display: inline-block;
    }

    .repo-title:hover {
      color: var(--link-hover-color);
      text-decoration: underline;
    }

    .repo-meta {
      display: flex;
      justify-content: space-between;
      align-items: center;
      margin-top: 0.4rem;
      flex-wrap: wrap;
      gap: 0.4rem;
    }

    .repo-description {
      font-size: 0.82rem;
      color: var(--muted-color);
      flex: 1;
      margin-right: 0.75rem;
    }

    .language-badge {
      display: flex;
      align-items: center;
      font-size: 0.78rem;
      color: var(--muted-color);
      border: 1px solid var(--border-color);
      border-radius: 20px;
      padding: 0.15rem 0.6rem;
      white-space: nowrap;
    }

    .language-dot {
      display: inline-block;
      width: 8px;
      height: 8px;
      border-radius: 50%;
      margin-right: 0.4rem;
    }

    .repository-content {
      padding: 1rem 1.5rem 1.25rem;
    }

    .repository-content p {
      font-size: 0.88rem;
      margin-bottom: 0.75rem;
    }

    .read-more {
      font-size: 0.82rem;
      color: var(--accent-color);
      font-weight: 500;
    }

    .read-more:hover {
      color: var(--link-hover-color);
      text-decoration: underline;
    }

    @media (max-width: 768px) {
      .repo-description {
        margin-right: 0;
      }
    }
    """


cssStyles : Html msg
cssStyles =
    VirtualDom.node "style" [] [ text css ]
