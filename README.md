# sw2iphone
A command line tool to export [Swinsian](https://swinsian.com/) playlists to iTunes/Music and sync back playcounts and ratings.
* Converts FLAC files to mp3 (requires sox and lame) as needed. Tries (not too hard) to find cover images (cover.jpg, etc), and include them (requires metaflac).
* Reads song data from the iTunesLibrary Framework (macOS 10.15+). (Thanks to code from the [idbcl](https://github.com/jmkerr/idbcl/) project.)
* Keeps track of files being removed from iTunes, so that we can keep proper count of playcount, and remove files from disk that we created.
### Install:
* Download `sw2iphone.zip` from the latest [release](https://github.com/akda5id/sw2iphone/releases/tag/v0.2.0) and extract it and place in your $PATH (or reference it directly).
* If you have FLAC files you want to sync, make sure you have sox, lame, and metaflac installed in /usr/local/bin/. Recommend installing with homebrew for ease: `brew install flac`  `brew install lame` and `brew install sox`.
#### Usage:
`sw2iphone -h` will give the commands, but here is what you need to know:
* By default we will use the directory `~/Music/sw2iphone` as our export folder for playlists, and any mp3s we create. You can change this by passing in a path after `--path`. If you do change the path after mp3s have been created in the old path, be aware that we don't do anything to move them, and they will be recreated next time you export the playlist, and things will get funky (duplicated tracks in iTunes). Recommend you set the path to what you want from the start, and if you do change it later, either manually move over the files, or start fresh in iTunes. We do save the path, you don't have to pass it each time, just when you want to change it.
* On first run it will probably ask you if you want "Terminal to be able to control Swinsian". This is the sandbox permission request for AppleScript to work with Swinsian. You should say yes.
*  `--v` or `--vv` (and super secret option `--vvv`) will increase the amount of verbosity. Whichever is largest will be used, you don't need to include them all.
*  You can use the above along with `--dry-run` to get a feel for what sw2iphone will do on the run, with this flag we won't create files on disk (other than temp files, which we clean up), or make changes to the Swinsian database.
*  For more see the workflows section below for examples.
#### Status and future features:
This is a tool I hacked up to fill a need of mine (to get music from Swinsian to my iPhone, and sync back playcounts and ratings). It is pretty simple, and may break in bad ways if you are doing something other than my specific workflow (see workflows below). That said I think other people may have needs similar to mine, so I am releasing it here under the MIT license. And I do intend to continue work to clean it up, make it more robust, and add a few features. Send me mail if you have problems, requests or just to let me know you are using it.
##### Todo:
* Provide support for an alternate workflow where we remove files if they are not exported from Swinsian in a while.
* Better status messages and logging.
* Potential performance improvements. I am using AppleScript to get track info out of Swinsian, as it doesn't persist smart playlists to its' database. This is kinda slow, so may be worth enabling a workflow where you would export a (smart) playlist manually from Swinsian, then I could run on that faster, perhaps. But really, the speed hit from AppleScript doesn't much matter if you are converting any FLACs. On that note, I am intentionally single threaded, as I am on a laptop and a prefer not spinning my fans up, and I don't mind waiting a bit for my music to be ready. I suppose this is one of the first feature requests I am going to get however :p
* I guess some configurability around lame and sox options would be nice to have. Though I think I have good defaults, I suppose a switch for -V 2 rather than -V 0 would be good. If you care you can just edit the code ;)
### Workflows:
For now, just one supported, mine :p
1) Run `sw2iphone -e` and pick which Swinsian playlist you want to export.
2) Drop the .m3u8 from the output directory (default `~/Music/sw2iphone`) into iTunes. (You have to do this manually as iTunesLibrary Framework is read only.)
3) Do whatever you want inside iTunes to sync files to your phone, or whatever. You can create smart playlists inside iTunes if you want, it doesn't have to be the playlist you imported that is synced. You can also import multiple playlists from Swinsian (by running `sw2iphone -e` again). We will keep track of playcounts and ratings for any files that we know about (that came in via any export from Swinsian). Other tracks existing inside of iTunes that we don't know about will be ignored.
4) Listen to things, rate them, etc.
5) Sync iTunes to your phone again to pick up playcounts, ratings.
6) Run `sw2iphone -s` to sync that info back into Swinsian.
7) Before you run `sw2iphone -s`  again, you must quit Swinsian, as it doesn't persist changes to its' database until quit.

When you have files you no longer need in iTunes, you should delete them from iTunes (recommend a smart playlist to help you find these). On the next `sw2iphone -s`  we will detect they have been removed, and handle them, including removing from disk if you include the `-c` flag.

iTunes ignores files that it already knows about when you import a playlist, so feel free to export playlists using `-e` as many times over as you like, even if most of the files are duplicates. (iTunes will create a duplicate playlist, so you will need to clean up old ones before bringing it in again.) I have a smart playlist in Swinsian for unplayed and unrated songs, and continuously export that, and bring it to my phone. Then as they get played and rated, the `-s` syncs back to Swinsian drop those files from that playlist, which I export back to iTunes again, ad nauseam. However this workflow doesn't remove files from iTunes when they are dropped from the Swinsian playlist. That is a feature I plan to add, but in the meantime, you can add a smart playlist in iTunes to search for the files that would be dropped on the Swinsian side (for myself with playcount > 0 or rating > 0) and then manually delete from iTunes library all files that match. Then the next `-s` will pick those up.
