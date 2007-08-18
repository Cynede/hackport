module P2 where

-- Module that respect categories.
-- Possibly to replace Portage.hs when the rest of the project has been
-- ported to this style.

import BlingBling

import Control.Arrow
import Control.Monad

import Data.Map (Map)
import qualified Data.Map as Map
import Data.Maybe
import qualified Data.List as List

import System.Directory
import System.IO
import System.FilePath

import Text.Regex

import Version

type Portage = PortageMap [Ebuild]
type PortageMap a = Map Package a

data Ebuild = Ebuild {
    ePackage :: Package,
    eVersion :: Version,
    eFilePath :: FilePath }
        deriving (Eq, Ord, Show)

data Package = P String String
    deriving (Eq, Ord)

instance Show Package where
    show (P c p) = c ++ '/':p

lookupEbuildWith :: Portage -> Package -> (Ebuild -> Bool) -> Maybe Ebuild
lookupEbuildWith portage package comp = do
    es <- Map.lookup package portage
    List.find comp es

getPackageList :: FilePath -> IO [Package]
getPackageList portdir = do
    categories <- getDirectories portdir
    packages <- fmap concat $ forMbling categories $ \c -> do
        pkg <- getDirectories (portdir </> c)
        return (map (P c) pkg)
    return packages

readPortagePackages :: FilePath -> [Package] -> IO Portage
readPortagePackages portdir packages0 = do
    packages <- filterM (doesDirectoryExist . (portdir </>) . show) packages0
    ebuild_map0 <- forM packages $ \package -> do
        ebuilds <- getPackageVersions package
        return (package, ebuilds)
    let ebuild_map = filter (not . null . snd) ebuild_map0
    return $ Map.fromList ebuild_map

    where
    getPackageVersions :: Package -> IO [Ebuild]
    getPackageVersions (P category package) = do
        files <- getDirectoryContents (portdir </> category </> package)
        let ebuilds = [ (v, portdir </> category </> package </> fn)
                      | (Just v, fn) <- map ((filterVersion package) &&& id) files ]
        return (map (uncurry (Ebuild (P category package))) ebuilds)

    filterVersion :: String -> String -> Maybe Version
    filterVersion p fn = do
        [vstring] <- matchRegex (ebuildVersionRegex p) fn
        case (parseVersion vstring) of
            Left e -> fail (show e)
            Right v -> return v

    ebuildVersionRegex name = mkRegex ("^"++name++"-(.*)\\.ebuild$")

readPortageTree :: FilePath -> IO Portage
readPortageTree portdir = do
    packages <- getPackageList portdir
    readPortagePackages portdir packages

getDirectories :: FilePath -> IO [String]
getDirectories fp = do
    files <- fmap (filter (`notElem` [".", ".."])) $ getDirectoryContents fp
    filterM (doesDirectoryExist . (fp </>)) files

printPortage :: Portage -> IO ()
printPortage port =
    forM_ (Map.toAscList port) $ \(package, ebuilds) -> do
        let (P c p) = package
        putStr $ c ++ '/':p
        putStr " "
        forM_ ebuilds (\e -> putStr (show  $ eVersion e) >> putChar ' ')
        putStrLn ""
