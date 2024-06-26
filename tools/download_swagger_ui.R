library(magrittr)
library(devtools)
library(rvest)

for (swagger_ui_version in c("3.52.5", "4.19.1", "5.17.14")) {

  local({

    major_version <- strsplit(swagger_ui_version, ".", fixed = TRUE)[[1]][[1]]

    to_location <- file.path(
      ".",
      "inst",
      paste0(
        "dist",
        major_version
      )
    )

    unlink(to_location, recursive = TRUE)
    dir.create(to_location, recursive = TRUE)

    swagger_release <- paste0("https://unpkg.com/swagger-ui-dist@", swagger_ui_version, "/")
    files <- read_html(swagger_release) %>% html_nodes(".css-xt128v") %>% html_attr("href")

    lapply(files, function(f) {
      # files are large and make CRAN upset
      if (grepl("\\.map$", f)) return()
      # files are not included in html
      if (grepl("es-bundle", f)) return()

      res <- download.file(paste0(swagger_release, f), file.path(to_location, f), mode = "wb")
      if (res != 0L) {
        message(paste("Download of", f, "failed."))
      }
      names(res) <- f
      res == 0
    })

    # shim in rstudio/swagger config settings
    index_html_file <- file.path(to_location, "index.html")
    index_html <- readLines(index_html_file)

    if (major_version == "3") {

      petstore_line <- which(grepl("https://petstore.swagger.io/v2/swagger.json", index_html, fixed = TRUE))
      stopifnot(length(petstore_line) > 0)

      updated_html <- append(
        index_html,
        c(
          "        validatorUrl: null, // disable validation",
          "        // https://github.com/rstudio/swagger/pull/19",
          "        syntaxHighlight: {",
          "          activated: false,",
          "          theme: \"agate\"",
          "        },"
        ),
        after = petstore_line
      )

    } else if (major_version %in% c("4", "5")) {

      initializer_file <- file.path(to_location, "swagger-initializer.js")
      initializer <- readLines(initializer_file)
      petstore_line <- which(grepl("https://petstore.swagger.io/v2/swagger.json", initializer, fixed = TRUE))
      stopifnot(length(petstore_line) > 0)

      updated_initializer <- append(
        initializer,
        c(
          "    validatorUrl: null, // disable validation",
          "    // https://github.com/rstudio/swagger/pull/19",
          "    syntaxHighlight: {",
          "      activated: false,",
          "      theme: \"agate\"",
          "    },"
        ),
        after = petstore_line
      )

      initializer_line <- which(grepl("./swagger-initializer.js", index_html, fixed = TRUE))
      stopifnot(length(initializer_line) > 0)

      updated_html <- append(
        index_html,
        c(
          "    <script>",
          paste0("    ", updated_initializer),
          "    </script>"
        ),
        after = initializer_line
      )[-initializer_line]

    }

    writeLines(updated_html, index_html_file)

  })

}
