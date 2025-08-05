module Projects exposing (viewProjects, cssStyles)

import Html exposing (..)
import Html.Attributes exposing (..)
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
    [ { name = "KaitoianOS"
      , url = "https://github.com/KaitoTLex/KaitoianOS"
      , description = "KaitoTLex's Mafuyu themed Hyprland on NixOS"
      , language = "Nix"
      , languageColor = "#817c95"  -- Fixed: Added valid color from palette
      , readmeExcerpt = "Fully customizable container-based operating system based on NixOS running Hyprland && Hyprscroller."
      }
    ]


viewRepository : Repository -> Html msg
viewRepository repo =
    div [ class "repository-card" ]
        [ div [ class "repository-header" ]
            [ h2 [] [ a [ href repo.url, class "repo-title" ] [ text repo.name ] ]
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
            , a [ href (repo.url ++ "/blob/main/README.md"), class "read-more" ] [ text "Read more →" ]  -- Fixed: Added parentheses for string concatenation
            ]
        ]


css : String
css =
    """
    .projects-container {
      max-width: 1200px;
      margin: 0 auto;
      padding: 2rem;
    }
    
    .projects-header {
      font-size: 2.5rem;
      margin-bottom: 0.5rem;
      color: var(--text-color);
    }
    
    .projects-subheader {
      font-size: 1.2rem;
      color: var(--text-secondary);
      margin-bottom: 2rem;
    }
    
    .projects-grid {
      display: grid;
      grid-template-columns: repeat(auto-fill, minmax(400px, 1fr));
      gap: 1.5rem;
    }
    
    .repository-card {
      background-color: var(--card-bg);
      border-radius: 8px;
      overflow: hidden;
      box-shadow: 0 2px 10px rgba(0,0,0,0.1);
      transition: transform 0.2s ease, box-shadow 0.2s ease;
    }
    
    .repository-card:hover {
      transform: translateY(-5px);
      box-shadow: 0 5px 15px rgba(0,0,0,0.15);
    }
    
    .repository-header {
      padding: 1.5rem;
      border-bottom: 1px solid var(--border-color);
    }
    
    .repo-title {
      color: var(--link-color);
      text-decoration: none;
      font-size: 1.5rem;
      display: inline-block;
    }
    
    .repo-title:hover {
      text-decoration: underline;
    }
    
    .repo-meta {
      display: flex;
      justify-content: space-between;
      align-items: center;
      margin-top: 0.5rem;
      flex-wrap: wrap;
      gap: 0.5rem;
    }
    
    .repo-description {
      color: var(--text-secondary);
      font-size: 0.95rem;
      flex: 1;
      margin-right: 1rem;
    }
    
    .language-badge {
      display: flex;
      align-items: center;
      background-color: var(--language-bg);
      border-radius: 20px;
      padding: 0.25rem 0.75rem;
      font-size: 0.85rem;
    }
    
    .language-dot {
      display: inline-block;
      width: 10px;
      height: 10px;
      border-radius: 50%;
      margin-right: 0.5rem;
    }
    
    .repository-content {
      padding: 1.5rem;
    }
    
    .read-more {
      display: inline-block;
      color: var(--link-color);
      text-decoration: none;
      margin-top: 0.5rem;
      font-weight: 500;
    }
    
    .read-more:hover {
      text-decoration: underline;
    }
    
    @media (max-width: 768px) {
      .projects-grid {
        grid-template-columns: 1fr;
      }
      
      .repo-description {
        margin-right: 0;
      }
    }
    """


cssStyles : Html msg
cssStyles =
    VirtualDom.node "style" [] [ text <| buildCss css ]


buildCss : String -> String
buildCss baseCss =
    """
    :root {
      --english-violet: #3d3653;
      --english-violet-2: #423b58;
      --english-violet-3: #463f5c;
      --english-violet-4: #4e4864;
      --ultra-violet: #5f5974;
      --cool-gray: #817c95;
      --rose-quartz: #a39fb6;
      --french-gray: #c5c2d6;
    }
    
    body.dark-mode {
      --background: var(--english-violet);
      --text-color: var(--french-gray);
      --text-secondary: var(--rose-quartz);
      --card-bg: var(--english-violet-4);
      --border-color: var(--ultra-violet);
      --link-color: var(--cool-gray);
      --language-bg: rgba(255, 255, 255, 0.08);
    }
    
    body.light-mode {
      --background: var(--french-gray);
      --text-color: var(--english-violet);
      --text-secondary: var(--ultra-violet);
      --card-bg: white;
      --border-color: var(--cool-gray);
      --link-color: var(--ultra-violet);
      --language-bg: rgba(0, 0, 0, 0.04);
    }
    
    body {
      background-color: var(--background);
      color: var(--text-color);
      transition: background-color 0.3s ease, color 0.3s ease;
    }
    """ ++ baseCss