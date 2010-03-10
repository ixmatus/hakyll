-- | A Module that allows easy rendering of RSS feeds. If you use this module,
--   you must make sure you set the `absoluteUrl` field in the main Hakyll
--   configuration.
--
--   Apart from that, the main rendering functions (@renderRss@,
--   @renderRssWith@, @renderAtom@ all @renderAtomWith@) all assume that you
--   pass the list of @Renderable@s so that the most recent entry in the feed is
--   the first item in the list.
--
--   Also note that the @Renderable@s should have (at least) the following
--   fields to produce a correct feed:
--
--   - @$title@: Title of the item.
--
--   - @$description@: Description to appear in the feed.
--
--   - @$url@: URL to the item - this is usually set automatically.
--
--   Furthermore, the feed will not validate if an empty list is passed.
module Text.Hakyll.Feed
    ( FeedConfiguration (..)
    , renderRss
    , renderRssWith
    , renderAtom
    , renderAtomWith
    ) where

import Control.Arrow ((>>>), second)
import Control.Monad.Reader (liftIO)
import Data.Maybe (fromMaybe)
import qualified Data.Map as M

import Text.Hakyll.Context (ContextManipulation, renderDate)
import Text.Hakyll.Hakyll (Hakyll)
import Text.Hakyll.Render (render, renderChain)
import Text.Hakyll.Renderables (createListingWith)
import Text.Hakyll.HakyllAction

import Paths_hakyll

-- | This is a data structure to keep the configuration of a feed.
data FeedConfiguration = FeedConfiguration
    { -- | Url of the feed (relative to site root). For example, @rss.xml@.
      feedUrl         :: String
    , -- | Title of the feed.
      feedTitle       :: String
    , -- | Description of the feed.
      feedDescription :: String
    , -- | Name of the feed author.
      feedAuthorName  :: String
    }

-- | This is an auxiliary function to create a listing that is, in fact, a feed.
--   The items should be sorted on date.
createFeedWith :: ContextManipulation -- ^ Manipulation to apply on the items.
               -> FeedConfiguration   -- ^ Feed configuration.
               -> [Renderable]        -- ^ Items to include.
               -> FilePath            -- ^ Feed template.
               -> FilePath            -- ^ Item template.
               -> Renderable
createFeedWith manipulation configuration renderables template itemTemplate =
    listing >>> render template
  where
    listing = createListingWith manipulation (feedUrl configuration)
                                [itemTemplate] renderables additional

    additional = map (second $ Left . ($ configuration))
        [ ("title", feedTitle)
        , ("description", feedDescription)
        , ("authorName", feedAuthorName)
        ] ++ updated

    -- Take the first timestamp, which should be the most recent.
    updated = let action = createHakyllAction $
                                return . fromMaybe "foo" . M.lookup "timestamp"
                  manip = createManipulationAction manipulation
                  toTuple r = ("timestamp", Right $ r >>> manip >>> action)
              in map toTuple $ take 1 renderables
            

-- | Abstract function to render any feed.
renderFeedWith :: ContextManipulation -- ^ Manipulation to apply on the items.
               -> FeedConfiguration   -- ^ Feed configuration.
               -> [Renderable]        -- ^ Items to include in the feed.
               -> FilePath            -- ^ Feed template.
               -> FilePath            -- ^ Item template.
               -> Hakyll ()
renderFeedWith manipulation configuration renderables template itemTemplate = do
    template' <- liftIO $ getDataFileName template
    itemTemplate' <- liftIO $ getDataFileName itemTemplate
    let renderFeedWith' = createFeedWith manipulation configuration
                                         renderables template' itemTemplate'
    renderChain [] renderFeedWith'

-- | Render an RSS feed with a number of items.
renderRss :: FeedConfiguration -- ^ Feed configuration.
          -> [Renderable]      -- ^ Items to include in the RSS feed.
          -> Hakyll ()
renderRss = renderRssWith id

-- | Render an RSS feed with a number of items. This function allows you to
--   specify a @ContextManipulation@ which will be applied on every
--   @Renderable@. Note that the given @Renderable@s should be sorted so the
--   most recent one is first.
renderRssWith :: ContextManipulation -- ^ Manipulation to apply on the items.
              -> FeedConfiguration   -- ^ Feed configuration.
              -> [Renderable]        -- ^ Items to include in the feed.
              -> Hakyll ()
renderRssWith manipulation configuration renderables =
    renderFeedWith manipulation' configuration renderables
                   "templates/rss.xml" "templates/rss-item.xml"
  where
    manipulation' = manipulation . renderRssDate

-- | @ContextManipulation@ that renders a date to RSS format.
renderRssDate :: ContextManipulation
renderRssDate = renderDate "timestamp" "%a, %d %b %Y %H:%M:%S UT"
                           "No date found."

-- | Render an Atom feed with a number of items.
renderAtom :: FeedConfiguration
           -> [Renderable]
           -> Hakyll ()
renderAtom = renderAtomWith id

-- | A version of @renderAtom@ that allows you to specify a manipulation to
--   apply on the @Renderable@s.
renderAtomWith :: ContextManipulation -- ^ Manipulation to apply on the items.
               -> FeedConfiguration   -- ^ Feed configuration.
               -> [Renderable]        -- ^ Items to include in the feed.
               -> Hakyll ()
renderAtomWith manipulation configuration renderables =
    renderFeedWith manipulation' configuration renderables
                   "templates/atom.xml" "templates/atom-item.xml"
  where
    manipulation' = manipulation . renderAtomDate

-- | Render a date to Atom format.
renderAtomDate :: ContextManipulation
renderAtomDate = renderDate "timestamp" "%Y-%m-%dT%H:%M:%SZ" "No date found."