package pl.klibert.klibgen.core

import kotlinx.collections.immutable.persistentListOf

object SampleBlogPosts {
    fun representative(): BlogPost =
        BlogPost(
            slug = "legacy-migration-sketch",
            metadata = PostMetadata(
                title = "Legacy migration sketch",
                publication = PublicationState.Published(publishedAt = "2026-06-17"),
                author = Author(name = "Klibert"),
                tags = persistentListOf("legacy", "migration"),
                legacyIds = persistentListOf("old-post-42"),
            ),
            nodes = persistentListOf(
                PostNode.Section(
                    heading = PostNode.Heading(
                        level = 2,
                        id = "intro",
                        content = persistentListOf(PostNode.Text("Intro")),
                    ),
                    content = persistentListOf(
                        PostNode.DomFragment(
                            tagName = "p",
                            children = persistentListOf(
                                PostNode.Text("The old renderer emitted custom nodes."),
                                PostNode.MyImage(
                                    src = "/images/io_message_send.png",
                                    alt = "IO message flow",
                                    caption = "A legacy my-img node.",
                                ),
                                PostNode.FootnoteReference(id = "n1"),
                            ),
                        ),
                        PostNode.FootnoteDefinition(
                            id = "n1",
                            content = persistentListOf(PostNode.Text("Preserve notes.")),
                        ),
                    ),
                ),
            ),
        )
}
