module Main exposing (main)

import Browser
import Browser.Navigation exposing (Key)
import Html exposing (Html, a, button, div, footer, h1, h2, img, p, span, text)
import Html.Attributes exposing (alt, class, href, src, style)
import Html.Events exposing (onClick)
import Url
import Url.Parser as Parser exposing (Parser, map, oneOf, s, top)
import VirtualDom
import Projects


main : Program () Model Msg
main =
    Browser.application
        { init = init
        , update = update
        , subscriptions = subscriptions
        , view = view
        , onUrlChange = UrlChanged
        , onUrlRequest = LinkClicked
        }


-- MODEL


type ColorMode
    = LightMode
    | DarkMode


type Page
    = Home
    | ProjectsPage
    | NotFound


type alias Model =
    { key : Key
    , url : Url.Url
    , colorMode : ColorMode
    , commitHash : String
    , mobileMenuOpen : Bool
    }


init : () -> Url.Url -> Key -> ( Model, Cmd Msg )
init _ url key =
    ( { key = key
      , url = url
      , colorMode = DarkMode
      , commitHash = "GITHUB_ACTIONS_COMMIT_HASH_PLACEHOLDER"
      , mobileMenuOpen = False
      }
    , Cmd.none
    )


-- UPDATE


type Msg
    = LinkClicked Browser.UrlRequest
    | UrlChanged Url.Url
    | ToggleColorMode
    | ToggleMobileMenu


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        LinkClicked urlRequest ->
            case urlRequest of
                Browser.Internal url ->
                    ( model, Browser.Navigation.pushUrl model.key (Url.toString url) )

                Browser.External href ->
                    ( model, Browser.Navigation.load href )

        UrlChanged url ->
            ( { model | url = url }, Cmd.none )

        ToggleColorMode ->
            let
                newMode =
                    if model.colorMode == DarkMode then
                        LightMode
                    else
                        DarkMode
            in
            ( { model | colorMode = newMode }, Cmd.none )

        ToggleMobileMenu ->
            ( { model | mobileMenuOpen = not model.mobileMenuOpen }, Cmd.none )


subscriptions : Model -> Sub Msg
subscriptions model =
    Sub.none


-- VIEW


view : Model -> Browser.Document Msg
view model =
    { title = "KaitoTLex.Systems"
    , body =
        [ css <| buildCss model
        , Projects.cssStyles
        , div [ class "container" ]
            [ div [ class "branding" ]
                [ div [ class "logo" ]
                    [ VirtualDom.node "svg"
                        [ Html.Attributes.attribute "viewBox" "0 0 24 24"
                        , Html.Attributes.attribute "width" "32"
                        , Html.Attributes.attribute "height" "32"
                        , style "margin-right" "1rem"
                        ]
                        [ VirtualDom.node "path"
                            [ Html.Attributes.attribute "d" "M12 2L2 7l10 5 10-5-10-5zM2 17l10 5 10-5M2 12l10 5 10-5" ]
                            []
                        ]
                    ]
                , h1 [] [ text "Ren Lin" ]
                , p [] [ text "kaitotlex.systems" ]
                , button [ class "mobile-menu-toggle", onClick ToggleMobileMenu ]
                    [ text (if model.mobileMenuOpen then "✕" else "☰") ]
                ]
            , div [ class "content-wrapper" ]
                [ if not model.mobileMenuOpen then
                    div [ class "sidebar" ]
                        [ h2 [] [ text "dir" ]
                        , div [ class "nav-links" ]
                            [ a [ href "/", onClick (LinkClicked (Browser.Internal (Url.fromString "/" |> Maybe.withDefault model.url))) ] [ text "home" ]
                            , a [ href "/about", onClick (LinkClicked (Browser.Internal (Url.fromString "/about" |> Maybe.withDefault model.url))) ] [ text "about" ]
                            , a [ href "/projects", onClick (LinkClicked (Browser.Internal (Url.fromString "/projects" |> Maybe.withDefault model.url))) ] [ text "projects" ]
                            , a [ href "https://eexiv.functor.systems/author/wlin" ] [ text "personal research" ]
                            , a [ href "https://yap.kaitotlex.systems" ] [ text "log" ]
                            , a [ href "https://cdn.example.com/resume.pdf" ] [ text "download CV" ]
                            ]
                        , h2 [] [ text "orgs" ]
                        , div [ class "org-links" ]
                            [ a [ href "https://functor.systems/" ] [ text "functor.systems" ]
                            , a [ href "https://inlabs.kaitotlex.systems" ] [ text "InLabs" ]
                            ]
                        , div [ class "mode-toggle-container" ]
                            [ button [ class "mode-toggle", onClick ToggleColorMode ]
                                [ text (if model.colorMode == DarkMode then "Light Mode" else "Dark Mode")
                                , span [ class "toggle-icon" ]
                                    [ if model.colorMode == DarkMode then
                                        VirtualDom.node "svg"
                                            [ Html.Attributes.attribute "viewBox" "0 0 24 24"
                                            , Html.Attributes.attribute "width" "16"
                                            , Html.Attributes.attribute "height" "16"
                                            ]
                                            [ VirtualDom.node "path"
                                                [ Html.Attributes.attribute "d" "M12 10c-1.1 0-2 .9-2 2s.9 2 2 2 2-.9 2-2-.9-2-2-2zm0-8c-3.3 0-6 2.7-6 6 0 1.8 0.8 3.4 2.1 4.5l-.2.3-1.9 2.8h10l-1.9-2.8-.2-.3c1.3-1.1 2.1-2.6 2.1-4.5 0-3.3-2.7-6-6-6zm-8 14v2h16v-2h-16z" ]
                                                []
                                            ]

                                      else
                                        VirtualDom.node "svg"
                                            [ Html.Attributes.attribute "viewBox" "0 0 24 24"
                                            , Html.Attributes.attribute "width" "16"
                                            , Html.Attributes.attribute "height" "16"
                                            ]
                                            [ VirtualDom.node "path"
                                                [ Html.Attributes.attribute "d" "M20 8.69V4h-4.69L12 .69 8.69 4H4v4.69L.69 12 4 15.31V20h4.69L12 23.31 15.31 20H20v-4.69L23.31 12 20 8.69zM12 18c-3.31 0-6-2.69-6-6s2.69-6 6-6 6 2.69 6 6-2.69 6-6 6zm0-10c-2.21 0-4 1.79-4 4s1.79 4 4 4 4-1.79 4-4-1.79-4-4-4z" ]
                                                []
                                            ]
                                    ]
                                ]
                            ]
                        ]

                  else
                    div [ class "mobile-menu-overlay" ]
                        [ div [ class "mobile-menu" ]
                            [ h2 [] [ text "Menu" ]
                            , div [ class "mobile-nav-links" ]
                                [ a [ href "/", onClick (LinkClicked (Browser.Internal (Url.fromString "/" |> Maybe.withDefault model.url))), class "mobile-nav-item" ] [ text "home" ]
                                , a [ href "/about", onClick (LinkClicked (Browser.Internal (Url.fromString "/about" |> Maybe.withDefault model.url))), class "mobile-nav-item" ] [ text "about" ]
                                , a [ href "/projects", onClick (LinkClicked (Browser.Internal (Url.fromString "/projects" |> Maybe.withDefault model.url))), class "mobile-nav-item" ] [ text "projects" ]
                                , a [ href "https://eexiv.functor.systems/author/wlin", class "mobile-nav-item" ] [ text "personal research" ]
                                , a [ href "https://yap.kaitotlex.systems", class "mobile-nav-item" ] [ text "log" ]
                                , a [ href "https://cdn.example.com/resume.pdf", class "mobile-nav-item" ] [ text "download CV" ]
                                ]
                            , h2 [] [ text "Organizations" ]
                            , div [ class "mobile-org-links" ]
                                [ a [ href "https://functor.systems/", class "mobile-nav-item" ] [ text "functor.systems" ]
                                , a [ href "https://inlabs.kaitotlex.systems", class "mobile-nav-item" ] [ text "InLabs" ]
                                ]
                            , button [ class "close-mobile-menu", onClick ToggleMobileMenu ] [ text "Close Menu" ]
                            ]
                        ]
                , div [ class "main-content" ]
                    [ case parseUrl model.url of
                        Home ->
                            div []
                                [ h1 [] [ text "oh Hi!" ]
                                , p [] [ text "I am Ren or Warren, I am a High School student studying Nuclear Theory and Electrical Engineering" ]
                                , img [ src "https://web.kaitotlex.systems/cont/bike.jpg", alt "Bike" ] []
                                , p [] [ text "I am interested in semi-conductor manufacturing, SOCs, and low power hardware. I work on projects that involves low power hardware -- anything RISC. I can't code. I like FOSS and FOSH, including RISC-V." ]
                                , p [] [ text "I like cycling and sim-racing. I watch MLB, NPB, F1, WEC, and WRC as a sport. I play the piano, bass and saxophone (Tenor && Alto). I do RE and hardware hacking in my freetime" ]
                                , p [] [ text "I play too much rythm games" ]
                                , p [] [ text "If you would like to learn more about me, send a Matrix message or read my logs." ]
                                , h2 [] [ text "contact" ]
                                , a [ href "https://web.kaitotlex.systems" ] [ text "kaitotlex.systems" ]
                                , a [ href "mailto:rlin@kaitotlex.systems" ] [ text "send a email (please sign with pgp)" ]
                                , a [ href "https://bsky.app/profile/kaitotlex.systems" ] [ text "bluesky" ]
                                , a [ href "https://x.com/Kaito_Malfoy" ] [ text "X (formerly twitter)" ]
                                , a [ href "https://github.com/kaitotlex" ] [ text "github" ]
                                , a [ href "https://osu.ppy.sh/users/26069038" ] [ text "osu" ]
                                , a [ href "https://arxiv.org/abs/2204.04549" ] [ text "send ripples through the maxwell matter wave" ]
                                ]

                        ProjectsPage ->
                            Projects.viewProjects

                        NotFound ->
                            div [ class "main-content" ]
                                [ h1 [] [ text "404 - Page Not Found" ]
                                , p [] [ text "The page you're looking for doesn't exist." ]
                                ]
                    ]
                ]
            , footer [ class "copyright-footer" ]
                [ text "2025 © KaitoTLex on Elm, all rights reserved"
                , span [ class "commit-info" ]
                    [ text " source: "
                    , a
                        [ href ("https://github.com/kaitotlex/web/commit/" ++ model.commitHash)
                        , class "commit-link"
                        ]
                        [ text model.commitHash ]
                    ]
                ]
            ]
        ]
    }


parseUrl : Url.Url -> Page
parseUrl url =
    case Parser.parse routeParser url of
        Just page ->
            page

        Nothing ->
            NotFound


routeParser : Parser (Page -> a) a
routeParser =
    oneOf
        [ Parser.map Home top
        , Parser.map Home (s "about")
        , Parser.map ProjectsPage (s "projects")
        ]


buildCss : Model -> String
buildCss model =
    let
        -- Direct color values based on current mode
        bg =
            if model.colorMode == DarkMode then
                "#3d3653"
            else
                "#c5c2d6"

        text =
            if model.colorMode == DarkMode then
                "#c5c2d6"
            else
                "#3d3653"

        brandingBg =
            if model.colorMode == DarkMode then
                "#4e4864"
            else
                "#a39fb6"

        sidebarBorder =
            if model.colorMode == DarkMode then
                "#5f5974"
            else
                "#817c95"

        buttonBg =
            if model.colorMode == DarkMode then
                "#5f5974"
            else
                "#817c95"

        buttonText =
            if model.colorMode == DarkMode then
                "#c5c2d6"
            else
                "#3d3653"

        linkColor =
            if model.colorMode == DarkMode then
                "#a39fb6"
            else
                "#5f5974"

        linkHover =
            "#817c95"
    in
    """
    @import url('https://fonts.googleapis.com/css2?family=Fira+Code:wght@400;500;600&display=swap');
    
    body {
      font-family: 'Fira Code', monospace;
      background-color: """ ++ bg ++ """;
      color: """ ++ text ++ """;
      line-height: 1.6;
      margin: 0;
      padding: 0;
      min-height: 100vh;
      transition: background-color 0.3s ease, color 0.3s ease;
    }
    
    a {
      color: """ ++ linkColor ++ """;
      text-decoration: none;
      transition: all 0.2s ease;
    }
    
    a:hover {
      color: """ ++ linkHover ++ """;
    }
    
    .container {
      max-width: 1200px;
      margin: 0 auto;
      padding: 2rem;
      display: flex;
      flex-direction: column;
      min-height: 100vh;
    }
    
    .branding {
      background-color: """ ++ brandingBg ++ """;
      padding: 1rem;
      text-align: center;
      position: sticky;
      top: 0;
      z-index: 100;
      display: flex;
      align-items: center;
      justify-content: center;
      gap: 0.5rem;
    }
    
    .logo {
      display: flex;
      align-items: center;
    }
    
    .content-wrapper {
      display: grid;
      grid-template-columns: 1fr 3fr;
      gap: 2rem;
      margin-top: 2rem;
      flex-grow: 1;
    }
    
    .sidebar {
      border-right: 1px solid """ ++ sidebarBorder ++ """;
      padding-right: 2rem;
    }
    
    .main-content {
      padding: 1rem 0;
    }
    
    h1, h2, h3 {
      color: """ ++ text ++ """;
      margin-top: 1.5rem;
    }
    
    .nav-links, .org-links {
      display: flex;
      flex-direction: column;
    }
    
    .nav-links a, .org-links a {
      display: block;
      padding: 0.75rem 0;
    }
    
    .mobile-menu-toggle {
      display: none;
      background: none;
      border: none;
      color: currentColor;
      font-size: 1.5rem;
      cursor: pointer;
      margin-left: auto;
    }
    
    .mobile-menu-overlay {
      position: fixed;
      top: 0;
      left: 0;
      width: 100%;
      height: 100%;
      background-color: rgba(0, 0, 0, 0.5);
      z-index: 999;
      display: flex;
      align-items: center;
    }
    
    .mobile-menu {
      background-color: """ ++ bg ++ """;
      width: 80%;
      max-width: 400px;
      height: 100%;
      padding: 2rem;
      overflow-y: auto;
    }
    
    .mobile-nav-links, .mobile-org-links {
      display: flex;
      flex-direction: column;
      margin-top: 1rem;
    }
    
    .mobile-nav-item {
      padding: 1rem 0;
      border-bottom: 1px solid """ ++ sidebarBorder ++ """;
    }
    
    .close-mobile-menu {
      background: none;
      border: none;
      color: currentColor;
      font-size: 1.5rem;
      cursor: pointer;
      margin-top: 1rem;
      width: 100%;
    }
    
    .copyright-footer {
      text-align: center;
      padding: 1.5rem 0;
      font-size: 0.85rem;
      opacity: 0.7;
      border-top: 1px solid """ ++ sidebarBorder ++ """;
      margin-top: auto;
    }
    
    .copyright-footer a {
      color: """ ++ linkColor ++ """;
      text-decoration: underline;
    }
    
    .copyright-footer a:hover {
      color: """ ++ linkHover ++ """;
      text-decoration: underline;
    }
    
    .mode-toggle {
      background-color: """ ++ buttonBg ++ """;
      color: """ ++ buttonText ++ """;
      border: none;
      padding: 0.75rem 1.5rem;
      border-radius: 4px;
      cursor: pointer;
      z-index: 1000;
      display: inline-flex;
      align-items: center;
      gap: 0.5rem;
      transition: all 0.3s ease;
      box-shadow: 0 2px 5px rgba(0,0,0,0.2);
      margin-top: 1rem;
    }
    
    .mode-toggle:hover {
      background-color: """ ++ linkHover ++ """;
      transform: translateY(-2px);
    }
    
    @media (max-width: 768px) {
      .content-wrapper {
        grid-template-columns: 1fr;
      }
      
      .sidebar {
        display: none;
      }
      
      .mobile-menu-toggle {
        display: block;
      }
      
      .mobile-menu {
        width: 90%;
      }
      
      .nav-links a, .org-links a {
        padding: 0.5rem 0;
      }
      
      .mode-toggle {
        padding: 0.5rem 1rem;
        font-size: 0.9rem;
      }
    }
    """


css : String -> Html msg
css cssContent =
    VirtualDom.node "style" [] [ text cssContent ]