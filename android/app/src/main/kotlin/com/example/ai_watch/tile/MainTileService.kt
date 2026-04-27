package com.example.ai_watch.tile

import androidx.wear.tiles.RequestBuilders
import androidx.wear.tiles.ResourceBuilders
import androidx.wear.tiles.TileBuilders
import androidx.wear.tiles.TileService
import androidx.wear.tiles.TimelineBuilders
import androidx.wear.tiles.LayoutElementBuilders
import androidx.wear.tiles.ModifiersBuilders
import androidx.wear.tiles.ActionBuilders
import androidx.wear.tiles.DimensionBuilders
import com.example.ai_watch.R
import com.google.common.util.concurrent.Futures
import com.google.common.util.concurrent.ListenableFuture

class MainTileService : TileService() {
    companion object {
        private const val RESOURCES_VERSION = "4"
        private const val LOGO_RESOURCE_ID = "ca_logo"
    }

    override fun onTileRequest(requestParams: RequestBuilders.TileRequest): ListenableFuture<TileBuilders.Tile> {
        val openAppAction = ActionBuilders.LaunchAction.Builder()
            .setAndroidActivity(
                ActionBuilders.AndroidActivity.Builder()
                    .setClassName("com.example.ai_watch.MainActivity")
                    .setPackageName(this.packageName)
                    .build()
            )
            .build()

        val startChatAction = ActionBuilders.LaunchAction.Builder()
            .setAndroidActivity(
                ActionBuilders.AndroidActivity.Builder()
                    .setClassName("com.example.ai_watch.StartChatActivity")
                    .setPackageName(this.packageName)
                    .build()
            )
            .build()

        val logoClickable = ModifiersBuilders.Clickable.Builder()
            .setId("open_app")
            .setOnClick(openAppAction)
            .build()

        val startChatClickable = ModifiersBuilders.Clickable.Builder()
            .setId("start_chat")
            .setOnClick(startChatAction)
            .build()

        val logoImage = LayoutElementBuilders.Image.Builder()
            .setResourceId(LOGO_RESOURCE_ID)
            .setWidth(DimensionBuilders.dp(64f))
            .setHeight(DimensionBuilders.dp(64f))
            .build()

        val logoCircle = LayoutElementBuilders.Box.Builder()
            .addContent(logoImage)
            .setModifiers(
                ModifiersBuilders.Modifiers.Builder()
                    .setClickable(logoClickable)
                    .build()
            )
            .setWidth(DimensionBuilders.dp(80f))
            .setHeight(DimensionBuilders.dp(80f))
            .setHorizontalAlignment(LayoutElementBuilders.HORIZONTAL_ALIGN_CENTER)
            .setVerticalAlignment(LayoutElementBuilders.VERTICAL_ALIGN_CENTER)
            .build()

        val startChatText = LayoutElementBuilders.Text.Builder()
            .setText("Start chat")
            .build()

        val startChatButton = LayoutElementBuilders.Box.Builder()
            .addContent(startChatText)
            .setModifiers(
                ModifiersBuilders.Modifiers.Builder()
                    .setClickable(startChatClickable)
                    .build()
            )
            .setWidth(DimensionBuilders.wrap())
            .setHeight(DimensionBuilders.wrap())
            .setHorizontalAlignment(LayoutElementBuilders.HORIZONTAL_ALIGN_CENTER)
            .setVerticalAlignment(LayoutElementBuilders.VERTICAL_ALIGN_CENTER)
            .build()

        val columnLayout = LayoutElementBuilders.Column.Builder()
            .addContent(logoCircle)
            .addContent(
                LayoutElementBuilders.Spacer.Builder()
                    .setHeight(DimensionBuilders.dp(8f))
                    .build()
            )
            .addContent(startChatButton)
            .setWidth(DimensionBuilders.wrap())
            .setHeight(DimensionBuilders.wrap())
            .setHorizontalAlignment(LayoutElementBuilders.HORIZONTAL_ALIGN_CENTER)
            .build()

        val centeredLayout = LayoutElementBuilders.Box.Builder()
            .addContent(columnLayout)
            .setWidth(DimensionBuilders.expand())
            .setHeight(DimensionBuilders.expand())
            .setHorizontalAlignment(LayoutElementBuilders.HORIZONTAL_ALIGN_CENTER)
            .setVerticalAlignment(LayoutElementBuilders.VERTICAL_ALIGN_CENTER)
            .build()

        val timeline = TimelineBuilders.Timeline.Builder()
            .addTimelineEntry(
                TimelineBuilders.TimelineEntry.Builder()
                    .setLayout(
                        LayoutElementBuilders.Layout.Builder()
                            .setRoot(centeredLayout)
                            .build()
                    )
                    .build()
            )
            .build()

        val tile = TileBuilders.Tile.Builder()
            .setResourcesVersion(RESOURCES_VERSION)
            .setTimeline(timeline)
            .build()

        return Futures.immediateFuture(tile)
    }

    override fun onResourcesRequest(requestParams: RequestBuilders.ResourcesRequest): ListenableFuture<ResourceBuilders.Resources> {
        return Futures.immediateFuture(
            ResourceBuilders.Resources.Builder()
                .setVersion(RESOURCES_VERSION)
                .addIdToImageMapping(
                    LOGO_RESOURCE_ID,
                    ResourceBuilders.ImageResource.Builder()
                        .setAndroidResourceByResId(
                            ResourceBuilders.AndroidImageResourceByResId.Builder()
                                .setResourceId(R.mipmap.ic_launcher)
                                .build()
                        )
                        .build()
                )
                .build()
        )
    }
}
