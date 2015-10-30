"use strict";

(function($) {
    /*
     * Crude expand/collapse function.
     * Table rows are not easily animated and cannot be hierarchically
     * grouped by markup.
     * Thus, the grouping is based on a hiearchic set of ids and classes
     * and no animation is used.
     */
    function initAccordions() {
        var hideText = "–";
        var showText = "+";
        var $button = $("<span/>")
            .attr("role", "button")
            .attr("tabindex", "0")
            .addClass("acct-grp-button")
            .text(hideText);
        $("tr.acct-grp-header")
            .addClass("acct-grp-header-expanded")
            .children("td.acct-name")
            .prepend($button);
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
                        .hide();
                    $("." + mainIdCls + " .acct-grp-button").text(showText);
                } else {
                    $("." + mainIdCls + ".acct-grp-header-collapsed")
                        .removeClass("acct-grp-header-collapsed")
                        .addClass("acct-grp-header-expanded")
                    $("." + mainIdCls)
                        .not($parent)
                        .show();
                    $("." + mainIdCls + " .acct-grp-button").text(hideText);
                }
                return false;
            });
    }

    /**
     * Create show splits dropdown.
     */
    function initShowSplits() {
        $(".has-splits .total").click(function() {
            var $this = $(this);
            var $splits = $this.next(".splits");
            if ($splits.hasClass("hidden")) {
                $(".splits:not(.hidden)").addClass("hidden");
                $splits.removeClass("hidden");
                
                // The next click closes the dropdown. If it's inside
                // the table, a link would have been clicked.
                $(window).one("click", function(event) {
                    $splits.addClass("hidden");
                });

                // Do no further if we show the splits table.
                // If the condition was false, the click will propagate
                // to the click handler on window.
                return false;
            }
        });
    }

    $(function() {
        initAccordions();
        initShowSplits();
    });
})(jQuery);
