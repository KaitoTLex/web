module Main exposing (main)

import About
import Browser
import Browser.Navigation exposing (Key)
import Home
import Html exposing (Html, a, button, div, h1, img, node, p, span, text)
import Html.Attributes exposing (alt, class, href, rel, src, type_)
import Html.Events exposing (onClick, stopPropagationOn)
import Http
import Json.Decode as Decode
import Projects
import Status
import Time
import Url
import Url.Parser as Parser exposing (Parser, oneOf, s, top)
import VirtualDom


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
    | AboutPage
    | ProjectsPage
    | StatusPage
    | NotFound


type alias Model =
    { key : Key
    , url : Url.Url
    , colorMode : ColorMode
    , commitHash : String
    , mobileMenuOpen : Bool
    , statusState : Status.StatusState
    }


init : () -> Url.Url -> Key -> ( Model, Cmd Msg )
init _ url key =
    let
        initialPage =
            case Parser.parse routeParser url of
                Just page ->
                    page

                Nothing ->
                    NotFound

        onStatusPage =
            initialPage == StatusPage
    in
    ( { key = key
      , url = url
      , colorMode = DarkMode
      , commitHash = "GITHUB_ACTIONS_COMMIT_HASH_PLACEHOLDER"
      , mobileMenuOpen = False
      , statusState =
            if onStatusPage then
                Status.StatusLoading

            else
                Status.StatusIdle
      }
    , if onStatusPage then Status.fetchApi StatusApiResult else Cmd.none
    )


-- UPDATE


type Msg
    = LinkClicked Browser.UrlRequest
    | UrlChanged Url.Url
    | ToggleColorMode
    | ToggleMobileMenu
    | NoOp
    | StatusApiResult (Result Http.Error (List Status.StatusSnapshot))
    | RefreshStatuses
    | Tick Time.Posix


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        LinkClicked urlRequest ->
            case urlRequest of
                Browser.Internal url ->
                    ( model, Browser.Navigation.pushUrl model.key (Url.toString url) )

                Browser.External href_ ->
                    ( model, Browser.Navigation.load href_ )

        UrlChanged url ->
            let
                newPage =
                    case Parser.parse routeParser url of
                        Just page ->
                            page

                        Nothing ->
                            NotFound

                onStatusPage =
                    newPage == StatusPage
            in
            ( { model
                | url = url
                , mobileMenuOpen = False
                , statusState =
                    if onStatusPage then
                        Status.StatusLoading

                    else
                        model.statusState
              }
            , if onStatusPage then Status.fetchApi StatusApiResult else Cmd.none
            )

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

        NoOp ->
            ( model, Cmd.none )

        StatusApiResult result ->
            ( { model
                | statusState =
                    case result of
                        Ok history ->
                            Status.StatusLoaded history

                        Err _ ->
                            Status.StatusFailed "could not reach /status.json"
              }
            , Cmd.none
            )

        RefreshStatuses ->
            ( { model | statusState = Status.StatusLoading }
            , Status.fetchApi StatusApiResult
            )

        Tick _ ->
            ( model, Status.fetchApi StatusApiResult )


subscriptions : Model -> Sub Msg
subscriptions model =
    case parseUrl model.url of
        StatusPage ->
            Time.every (60 * 1000) Tick

        _ ->
            Sub.none


-- NAVIGATION DATA


navItems : List ( String, String )
navItems =
    [ ( "/", "home" )
    , ( "/about", "about" )
    , ( "/projects", "projects" )
    , ( "/status", "status" )
    , ( "https://eexiv.functor.systems/author/wlin", "personal research" )
    , ( "https://yap.kaitotlex.systems", "log" )
    , ( "/cont/cv.pdf", "download cv" )
    ]


orgItems : List ( String, String )
orgItems =
    [ ( "https://functor.systems/", "functor.systems" )
    , ( "https://inlabs.kaitotlex.systems", "InLabs" )
    ]


-- VIEW HELPERS


css : String -> Html msg
css cssContent =
    VirtualDom.node "style" [] [ text cssContent ]


isActiveLink : Page -> String -> Bool
isActiveLink currentPage url =
    case ( currentPage, url ) of
        ( Home, "/" ) ->
            True

        ( AboutPage, "/about" ) ->
            True

        ( ProjectsPage, "/projects" ) ->
            True

        ( StatusPage, "/status" ) ->
            True

        _ ->
            False


viewSidebar : ColorMode -> String -> Page -> Html Msg
viewSidebar colorMode commitHash currentPage =
    let
        isPlaceholder =
            String.startsWith "GITHUB" commitHash

        shortHash =
            if isPlaceholder then
                "dev"

            else
                String.left 7 commitHash

        commitDisplay =
            if isPlaceholder then
                span [ class "commit-hash" ] [ text ("src: " ++ shortHash) ]

            else
                a
                    [ href ("https://github.com/KaitoTLex/web/commit/" ++ commitHash)
                    , class "commit-hash"
                    ]
                    [ text ("src: " ++ shortHash) ]

        navLinkItem ( url, label ) =
            a
                [ href url
                , class
                    (if isActiveLink currentPage url then
                        "nav-link active"

                     else
                        "nav-link"
                    )
                ]
                [ text label ]
    in
    div [ class "sidebar" ]
        [ div [ class "sidebar-identity" ]
            [ div [ class "sidebar-name" ] [ text "Ren Lin" ]
            , div [ class "sidebar-tagline" ] [ text "kaitotlex.systems" ]
            , div [ class "sidebar-location" ] [ img [ src "/assets/pcb.svg", alt "pcb traces"] [] ]
            ]
        , div [ class "sidebar-divider" ] []
        , div [ class "sidebar-section-label" ] [ text "dir" ]
        , div [ class "nav-links" ]
            (List.map navLinkItem navItems)
        , div [ class "sidebar-divider" ] []
        , div [ class "sidebar-section-label" ] [ text "orgs" ]
        , div [ class "org-links" ]
            (List.map
                (\( url, label ) -> a [ href url, class "nav-link" ] [ text label ])
                orgItems
            )
        , div [ class "sidebar-spacer" ] []
        , div [ class "sidebar-footer" ]
            [ button [ class "theme-toggle", onClick ToggleColorMode ]
                [ text
                    (if colorMode == DarkMode then
                        "[ light ]"

                     else
                        "[ dark ]"
                    )
                ]
            , commitDisplay
            ]
        ]


viewMobileMenu : ColorMode -> Page -> Html Msg
viewMobileMenu colorMode currentPage =
    let
        mobileNavItem ( url, label ) =
            a
                [ href url
                , class
                    (if isActiveLink currentPage url then
                        "mobile-nav-item active"

                     else
                        "mobile-nav-item"
                    )
                ]
                [ text label ]
    in
    div [ class "mobile-menu-wrapper" ]
        [ div [ class "mobile-menu-backdrop", onClick ToggleMobileMenu ] []
        , div
            [ class "mobile-menu-panel"
            , stopPropagationOn "click" (Decode.succeed ( NoOp, True ))
            ]
            [ div [ class "mobile-menu-header" ]
                [ div []
                    [ span [ class "mobile-menu-title" ] [ text "Ren Lin" ]
                    , div [ class "mobile-menu-location" ] [ img [ src "/assets/pcb.svg", alt "pcb traces" ] [] ]
                    ]
                , button [ class "close-mobile-menu", onClick ToggleMobileMenu ] [ text "✕" ]
                ]
            , div [ class "mobile-nav-section-label" ] [ text "dir" ]
            , div [ class "mobile-nav-links" ]
                (List.map mobileNavItem navItems)
            , div [ class "mobile-nav-section-label" ] [ text "orgs" ]
            , div [ class "mobile-org-links" ]
                (List.map
                    (\( url, label ) ->
                        a [ href url, class "mobile-nav-item" ] [ text label ]
                    )
                    orgItems
                )
            , button [ class "mobile-mode-toggle", onClick ToggleColorMode ]
                [ text
                    (if colorMode == DarkMode then
                        "[ light ]"

                     else
                        "[ dark ]"
                    )
                ]
            ]
        ]


viewPageFooter : String -> Html Msg
viewPageFooter commitHash =
    let
        isPlaceholder =
            String.startsWith "GITHUB" commitHash

        shortHash =
            if isPlaceholder then
                "dev"

            else
                String.left 7 commitHash
    in
    div [ class "page-footer" ]
        [ div [ class "footer-gifs" ]
            [ img [ src "/assets/gif/eva.gif", alt "eva" ] []
            , img [ src "/assets/gif/nec.gif", alt "nec" ] []
            , img [ src "/assets/gif/linux_powered.gif", alt "linux" ] []
            , img [ src "/assets/gif/yuri.png", alt "yuri" ] []
            , img [ src "/assets/gif/trans.gif", alt "trans" ] []
            , img [ src "/assets/gif/miku.gif", alt "miku" ] []
            , img [ src "/assets/gif/latex.gif", alt "latex" ] []
            , img [ src "/assets/gif/kaitotlex.gif", alt "self" ] []
            , img [ src "/assets/gif/tetris.gif", alt "tetris" ] []
            ]
        -- , img [ src "/assets/pcb.svg", alt "pcb traces", class "footer-pcb" ] []
        , if isPlaceholder then
            span [ class "footer-hash" ] [ text ("src: " ++ shortHash) ]

          else
            a
                [ href ("https://github.com/KaitoTLex/web/commit/" ++ commitHash)
                , class "footer-hash"
                ]
                [ text ("src: " ++ shortHash) ]
        ]


viewPage : Page -> Model -> Html Msg
viewPage page model =
    case page of
        Home ->
            Home.view

        AboutPage ->
            About.view

        ProjectsPage ->
            Projects.viewProjects

        StatusPage ->
            Status.view model.statusState RefreshStatuses

        NotFound ->
            div []
                [ h1 [] [ text "404" ]
                , p [] [ text "page not found." ]
                ]


-- VIEW


view : Model -> Browser.Document Msg
view model =
    let
        currentPage =
            parseUrl model.url
    in
    { title = "kaitotlex.systems"
    , body =
        [ node "link" [ rel "icon", type_ "image/png", href "/assets/favicon.png" ] []
        , css (buildCss model.colorMode)
        , Home.cssStyles
        , Status.cssStyles
        , Projects.cssStyles
        , div [ class "layout" ]
            [ div [ class "mobile-topbar" ]
                [ span [ class "mobile-site-name" ] [ text "Ren Lin" ]
                , button [ class "mobile-menu-toggle", onClick ToggleMobileMenu ]
                    [ text "☰"
                    , span [ class "sr-only" ] [ text "Menu" ]
                    ]
                ]
            , viewSidebar model.colorMode model.commitHash currentPage
            , div [ class "main-content" ]
                [ viewPage currentPage model
                , viewPageFooter model.commitHash
                ]
            , if model.mobileMenuOpen then
                viewMobileMenu model.colorMode currentPage

              else
                text ""
            ]
        ]
    }


-- ROUTING


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
        , Parser.map AboutPage (s "about")
        , Parser.map ProjectsPage (s "projects")
        , Parser.map StatusPage (s "status")
        ]


-- THEME


type alias Theme =
    { bg : String
    , sidebarBg : String
    , surface : String
    , border : String
    , fg : String
    , muted : String
    , accent : String
    , linkColor : String
    , linkHover : String
    }


themeFor : ColorMode -> Theme
themeFor colorMode =
    case colorMode of
        DarkMode ->
            { bg = "#1e1c2e"
            , sidebarBg = "#252334"
            , surface = "#2d2b3d"
            , border = "#3d3a52"
            , fg = "#e8e6f0"
            , muted = "#9e9ab8"
            , accent = "#c4a0c8"
            , linkColor = "#b8b4cc"
            , linkHover = "#d4d1e5"
            }

        LightMode ->
            { bg = "#f7f6fc"
            , sidebarBg = "#eeebf8"
            , surface = "#ffffff"
            , border = "#d8d5ea"
            , fg = "#1e1c2e"
            , muted = "#6b6785"
            , accent = "#7c78a8"
            , linkColor = "#5a5780"
            , linkHover = "#3d3a5e"
            }


buildCss : ColorMode -> String
buildCss colorMode =
    let
        t =
            themeFor colorMode
    in
    """
    @import url('https://fonts.googleapis.com/css2?family=Fira+Code:wght@300;400;500;600&display=swap');

    *, *::before, *::after {
      box-sizing: border-box;
    }

    html {
      scroll-behavior: smooth;
    }

    html, body {
      margin: 0;
      padding: 0;
      height: 100%;
    }

    :root {
      --border-color: """ ++ t.border ++ """;
      --surface-color: """ ++ t.surface ++ """;
      --accent-color: """ ++ t.accent ++ """;
      --muted-color: """ ++ t.muted ++ """;
      --text-color: """ ++ t.fg ++ """;
      --link-color: """ ++ t.linkColor ++ """;
      --link-hover-color: """ ++ t.linkHover ++ """;
    }

    body {
      font-family: 'Fira Code', monospace;
      background-color: """ ++ t.bg ++ """;
      color: """ ++ t.fg ++ """;
      font-size: 15px;
      line-height: 1.7;
      transition: background-color 0.25s ease, color 0.25s ease;
    }

    a {
      color: """ ++ t.linkColor ++ """;
      text-decoration: none;
      transition: color 0.15s ease;
    }

    a:hover {
      color: """ ++ t.linkHover ++ """;
    }

    /* ── Layout ─────────────────────────────────── */

    .layout {
      display: flex;
      min-height: 100vh;
      position: relative;
    }

    /* ── Sidebar ─────────────────────────────────── */

    .sidebar {
      position: fixed;
      left: 0;
      top: 0;
      width: 240px;
      height: 100vh;
      overflow-y: auto;
      display: flex;
      flex-direction: column;
      background-color: """ ++ t.sidebarBg ++ """;
      border-right: 1px solid """ ++ t.border ++ """;
      padding: 2rem 1.5rem;
      z-index: 100;
      transition: background-color 0.25s ease;
    }

    .sidebar-identity {
      margin-bottom: 1rem;
    }

    .sidebar-name {
      font-size: 1.05rem;
      font-weight: 600;
      color: """ ++ t.fg ++ """;
      letter-spacing: 0.02em;
    }

    .sidebar-tagline {
      font-size: 0.78rem;
      color: """ ++ t.muted ++ """;
      margin-top: 0.25rem;
    }

    .sidebar-location {
      font-size: 0.7rem;
      color: """ ++ t.muted ++ """;
      margin-top: 0.3rem;
      opacity: 0.75;
      letter-spacing: 0.02em;
    }

    .sidebar-divider {
      height: 1px;
      background-color: """ ++ t.border ++ """;
      margin: 1rem 0;
    }

    .sidebar-section-label {
      font-size: 0.7rem;
      font-weight: 500;
      text-transform: uppercase;
      letter-spacing: 0.1em;
      color: """ ++ t.muted ++ """;
      margin-bottom: 0.4rem;
    }

    .nav-links,
    .org-links {
      display: flex;
      flex-direction: column;
    }

    .nav-link {
      display: block;
      padding: 0.38rem 0.6rem;
      font-size: 0.86rem;
      color: """ ++ t.linkColor ++ """;
      border-left: 3px solid transparent;
      border-radius: 0 4px 4px 0;
      transition: color 0.15s ease, background-color 0.15s ease, border-left-color 0.15s ease;
    }

    .nav-link:hover {
      color: """ ++ t.linkHover ++ """;
      background-color: """ ++ t.surface ++ """;
      border-left-color: """ ++ t.accent ++ """;
    }

    .nav-link.active {
      color: """ ++ t.accent ++ """;
      border-left-color: """ ++ t.accent ++ """;
      background-color: """ ++ t.surface ++ """;
    }

    .sidebar-spacer {
      flex-grow: 1;
    }

    .sidebar-footer {
      display: flex;
      flex-direction: column;
      gap: 0.5rem;
      padding-top: 1rem;
      border-top: 1px solid """ ++ t.border ++ """;
    }

    .theme-toggle {
      background: none;
      border: 1px solid """ ++ t.border ++ """;
      color: """ ++ t.muted ++ """;
      font-family: 'Fira Code', monospace;
      font-size: 0.78rem;
      padding: 0.3rem 0.6rem;
      border-radius: 4px;
      cursor: pointer;
      text-align: left;
      transition: color 0.15s ease, border-color 0.15s ease;
      width: 100%;
    }

    .theme-toggle:hover {
      color: """ ++ t.fg ++ """;
      border-color: """ ++ t.accent ++ """;
    }

    .commit-hash {
      font-size: 0.72rem;
      color: """ ++ t.muted ++ """;
      opacity: 0.65;
    }

    a.commit-hash:hover {
      color: """ ++ t.linkHover ++ """;
      opacity: 1;
    }

    /* ── Main Content ────────────────────────────── */

    .main-content {
      margin-left: 240px;
      padding: 3.5rem 4rem;
      flex: 1;
      min-height: 100vh;
    }

    .main-content h1 {
      font-size: 1.8rem;
      font-weight: 600;
      color: """ ++ t.fg ++ """;
      margin-top: 0;
      margin-bottom: 0.5rem;
      letter-spacing: -0.01em;
    }

    .main-content h2 {
      font-size: 0.82rem;
      font-weight: 500;
      color: """ ++ t.muted ++ """;
      margin-top: 2rem;
      margin-bottom: 0.6rem;
      text-transform: uppercase;
      letter-spacing: 0.1em;
    }

    .main-content p {
      color: """ ++ t.fg ++ """;
      max-width: 600px;
      margin-bottom: 1rem;
      font-size: 0.93rem;
    }

    /* ── Page footer ────────────────────────────── */

    .page-footer {
      margin-top: 4rem;
      padding-top: 1rem;
      border-top: 1px solid """ ++ t.border ++ """;
    }

    .footer-hash {
      font-size: 0.72rem;
      color: """ ++ t.muted ++ """;
      opacity: 0.65;
    }

    a.footer-hash:hover {
      color: """ ++ t.linkHover ++ """;
      opacity: 1;
    }

    .footer-pcb {
      display: block;
      max-width: 340px;
      height: auto;
      margin-top: 0.5rem;
      opacity: 0.8;
    }

    .footer-gifs {
      display: flex;
      flex-wrap: wrap;
      gap: 0.25rem;
      margin-bottom: 0.75rem;
    }

    .footer-gifs img {
      height: 31px;
      image-rendering: pixelated;
    }

    /* ── About page ─────────────────────────────── */

    .about-content {
      max-width: 640px;
    }

    .about-para {
      margin-bottom: 1rem;
      line-height: 1.8;
      font-size: 0.93rem;
    }

    .about-quote {
      border-left: 2px solid """ ++ t.accent ++ """;
      padding: 0.75rem 1.25rem;
      margin: 1.5rem 0;
      background-color: """ ++ t.surface ++ """;
      border-radius: 0 4px 4px 0;
    }

    .quote-text {
      font-size: 0.88rem;
      color: """ ++ t.muted ++ """;
      margin: 0;
      font-style: italic;
      line-height: 1.7;
      max-width: 100%;
    }

    .quote-attribution {
      font-size: 0.75rem;
      color: """ ++ t.muted ++ """;
      opacity: 0.75;
      margin-top: 0.5rem;
      margin-bottom: 0;
    }

    .contact-links {
      display: flex;
      flex-direction: column;
      gap: 0.1rem;
      margin-top: 0.5rem;
    }

    .contact-item {
      display: block;
      padding: 0.38rem 0.6rem;
      font-size: 0.88rem;
      color: """ ++ t.linkColor ++ """;
      border-left: 3px solid transparent;
      border-radius: 0 4px 4px 0;
      transition: color 0.15s ease, background-color 0.15s ease, border-left-color 0.15s ease;
    }

    .contact-item::before {
      content: "→ ";
      color: """ ++ t.accent ++ """;
    }

    .contact-item:hover {
      color: """ ++ t.linkHover ++ """;
      background-color: """ ++ t.surface ++ """;
      border-left-color: """ ++ t.accent ++ """;
    }

    /* ── Mobile top bar ─────────────────────────── */

    .mobile-topbar {
      display: none;
      position: sticky;
      top: 0;
      z-index: 200;
      background-color: """ ++ t.sidebarBg ++ """;
      border-bottom: 1px solid """ ++ t.border ++ """;
      padding: 0.75rem 1.25rem;
      align-items: center;
      justify-content: space-between;
      width: 100%;
    }

    .mobile-site-name {
      font-size: 0.95rem;
      font-weight: 600;
      color: """ ++ t.fg ++ """;
    }

    .mobile-menu-toggle {
      background: none;
      border: none;
      color: """ ++ t.fg ++ """;
      font-size: 1.3rem;
      cursor: pointer;
      padding: 0.2rem 0.4rem;
      line-height: 1;
    }

    .sr-only {
      position: absolute;
      width: 1px;
      height: 1px;
      padding: 0;
      margin: -1px;
      overflow: hidden;
      clip: rect(0, 0, 0, 0);
      white-space: nowrap;
      border: 0;
    }

    /* ── Mobile menu ────────────────────────────── */

    .mobile-menu-wrapper {
      position: fixed;
      inset: 0;
      z-index: 300;
    }

    .mobile-menu-backdrop {
      position: absolute;
      inset: 0;
      background-color: rgba(0, 0, 0, 0.5);
    }

    .mobile-menu-panel {
      position: absolute;
      top: 0;
      right: 0;
      width: 280px;
      height: 100%;
      overflow-y: auto;
      background-color: """ ++ t.sidebarBg ++ """;
      border-left: 1px solid """ ++ t.border ++ """;
      padding: 1.5rem 1.25rem;
      display: flex;
      flex-direction: column;
    }

    .mobile-menu-header {
      display: flex;
      justify-content: space-between;
      align-items: center;
      margin-bottom: 1.25rem;
    }

    .mobile-menu-title {
      font-size: 0.7rem;
      font-weight: 500;
      color: """ ++ t.muted ++ """;
      text-transform: uppercase;
      letter-spacing: 0.1em;
    }

    .close-mobile-menu {
      background: none;
      border: none;
      color: """ ++ t.muted ++ """;
      font-size: 1rem;
      cursor: pointer;
      padding: 0.2rem 0.4rem;
      transition: color 0.15s ease;
    }

    .close-mobile-menu:hover {
      color: """ ++ t.fg ++ """;
    }

    .mobile-nav-section-label {
      font-size: 0.7rem;
      font-weight: 500;
      text-transform: uppercase;
      letter-spacing: 0.1em;
      color: """ ++ t.muted ++ """;
      margin-top: 1.25rem;
      margin-bottom: 0.4rem;
    }

    .mobile-nav-links,
    .mobile-org-links {
      display: flex;
      flex-direction: column;
    }

    .mobile-nav-item {
      display: block;
      padding: 0.5rem 0.6rem;
      font-size: 0.9rem;
      color: """ ++ t.linkColor ++ """;
      border-left: 3px solid transparent;
      border-radius: 0 4px 4px 0;
      transition: color 0.15s ease, background-color 0.15s ease, border-left-color 0.15s ease;
    }

    .mobile-nav-item:hover {
      color: """ ++ t.linkHover ++ """;
      background-color: """ ++ t.surface ++ """;
      border-left-color: """ ++ t.accent ++ """;
    }

    .mobile-mode-toggle {
      margin-top: auto;
      background: none;
      border: none;
      border-top: 1px solid """ ++ t.border ++ """;
      color: """ ++ t.muted ++ """;
      font-family: 'Fira Code', monospace;
      font-size: 0.8rem;
      padding: 0.75rem 0.6rem 0.4rem;
      cursor: pointer;
      text-align: left;
      transition: color 0.15s ease;
    }

    .mobile-mode-toggle:hover {
      color: """ ++ t.fg ++ """;
    }

    /* ── Responsive ─────────────────────────────── */

    .mobile-menu-location {
      font-size: 0.7rem;
      color: """ ++ t.muted ++ """;
      margin-top: 0.15rem;
      opacity: 0.75;
    }

    .mobile-nav-item.active {
      color: """ ++ t.accent ++ """;
      border-left-color: """ ++ t.accent ++ """;
      background-color: """ ++ t.surface ++ """;
    }

    @media (max-width: 768px) {
      .layout {
        flex-direction: column;
      }

      .sidebar {
        display: none;
      }

      .mobile-topbar {
        display: flex;
      }

      .main-content {
        margin-left: 0;
        padding: 1.75rem 1.25rem;
        max-width: 100%;
      }
    }

    @media (min-width: 769px) and (max-width: 1100px) {
      .sidebar {
        width: 200px;
      }

      .main-content {
        margin-left: 200px;
        padding: 2.5rem 2.5rem;
      }
    }
    """
