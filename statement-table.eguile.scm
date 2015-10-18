<!DOCTYPE html>
<html>
  <head>
    <meta charset="utf-8">
    <title><?scm:d title ?></title>
    <link rel="shylesheet" href="<?scm:d (find-file "normalize.css") ?>">
    <link rel="stylesheet" href="<?scm:d (find-file "statement-table.css") ?>">
  </head>
  <body>
    <h1>
      <?scm:d (xaccAccountGetName base-account) ?>
      <?scm:d (gnc-print-date from-date-tp) ?>
      <?scm:d (_ "to") ?>
      <?scm:d (gnc-print-date to-date-tp) ?>
    </h1>
    <table>
      <tr>
        <td></td>
        <?scm (for d in dates-list do ?>
        <td><?scm:d (format-date d) ?></td>
        <?scm ) ?>
        <td><?scm:d (_ "Total") ?></td>
      </tr>
      <?scm (for a-row in acct-rows do ?>
      <tr class="acct-level-<?scm:d (a-row 'depth)
            ?><?scm (and (a-row 'placeholder?) ?> acct-placeholder<?scm )
            ?> acct-cat-<?scm:d (a-row 'category-string) ?>">
        <td class="acct-name"><?scm:d (a-row 'name-format) ?></td>
        <?scm   (for (total splits) in
                     ((a-row 'periods-total-data)
                      (a-row 'periods-splits)) do ?>
        <td>
          <?scm:d (format-acct-number (total 'get-value) (a-row 'account)) ?>
          <div class="splits">
            <?scm (for split in splits do ?>
            <div>
              <?scm:d (xaccTransGetDescription (xaccSplitGetParent split)) ?>
              :
              <?scm:d (xaccAccountGetName (xaccSplitGetAccount split)) ?>
            </div>
            <?scm ) ?>
          </div>
        </td>
        <?scm   ) ?>
        <td><?scm:d (format-acct-number (a-row 'total) (a-row 'account)) ?></td>
      </tr>
      <?scm ) ?>
      <tr>
        <td><?scm:d (_ "Total") ?></td>
        <?scm (for totals in (periods-totals 'total) do ?>
        <td><?scm:d (format-number totals #t) ?></td>
        <?scm ) ?>
      </tr>
      <tr>
        <td><?scm:d (_ "Total minus assets") ?></td>
        <?scm (for totals in (periods-totals 'total-min-asset) do ?>
        <td><?scm:d (format-number totals #t) ?></td>
        <?scm ) ?>
      </tr>
      <tr>
        <td><?scm:d (_ "Total minus assets and liabilities") ?></td>
        <?scm (for totals in (periods-totals 'total-min-asset-liab) do ?>
        <td><?scm:d (format-number totals #t) ?></td>
        <?scm ) ?>
      </tr>
    </table>
  </body>
</html>
