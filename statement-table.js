"use strict";

(function($) {
    var animationTime = 200;

    /*
     * Crude animation function.
     * Table rows are not easily animated and cannot be hierarchically
     * grouped by markup.
     * Thus, the grouping is based on a hiearchic set of ids and classes
     * and fade is used for animation.
     */
    $(function() {
        var button = $("<span/>")
            .attr("role", "button")
            .attr("tabindex", "0")
            .addClass("acct-grp-button");
        $("tr.acct-grp-header")
            .addClass("acct-grp-header-expanded")
            .children("td.acct-name")
            .prepend(button);
        $(".acct-grp-button")
            .click(function() {
                var $this = $(this);
                var $parent = $this.parents("tr.acct-grp-header");
                var ids = $parent.attr('data-acct-grp-ids').split(" ");
                var mainIdCls = "acct-grp-id-" + ids.reverse().join("-");
                if ($parent.hasClass("acct-grp-header-expanded")) {
                    $("." + mainIdCls + ".acct-grp-header-expanded")
                        .removeClass("acct-grp-header-expanded")
                        .addClass("acct-grp-header-collapsed")
                    $("." + mainIdCls)
                        .not($parent)
                        .fadeOut(animationTime);
                } else {
                    $("." + mainIdCls + ".acct-grp-header-collapsed")
                        .removeClass("acct-grp-header-collapsed")
                        .addClass("acct-grp-header-expanded")
                    $("." + mainIdCls)
                        .not($parent)
                        .fadeIn(animationTime);
                }
            });
    });
})(jQuery);
