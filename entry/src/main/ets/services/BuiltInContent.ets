export class BuiltInContent {
  public static undercoverPairs(): string[][] {
    const contexts: string[] = [
      '校园', '旅行', '周末', '雨天', '夏日', '冬夜', '早餐', '运动', '电影', '音乐', '未来'
    ];
    const bases: string[][] = [
      ['图书馆', '自习室'], ['咖啡', '奶茶'], ['火锅', '麻辣烫'], ['雨伞', '遮阳伞'],
      ['钢笔', '铅笔'], ['地铁', '公交车'], ['电影', '电视剧'], ['相机', '摄像机'],
      ['篮球', '排球'], ['书包', '旅行箱'], ['饺子', '馄饨'], ['耳机', '音箱'],
      ['日出', '日落'], ['森林', '公园'], ['吉他', '尤克里里'], ['蛋糕', '面包'],
      ['医生', '护士'], ['地图', '导航'], ['钥匙', '门卡'], ['围巾', '领带'],
      ['火车', '高铁'], ['猫头鹰', '老鹰'], ['橙汁', '柠檬水'], ['冰箱', '空调'],
      ['风筝', '纸飞机'], ['月亮', '路灯'], ['跑步', '竞走'], ['露营', '野餐'],
      ['口琴', '笛子'], ['台灯', '手电筒']
    ];
    const result: string[][] = [];
    for (let contextIndex: number = 0; contextIndex < contexts.length; contextIndex += 1) {
      for (let baseIndex: number = 0; baseIndex < bases.length; baseIndex += 1) {
        result.push([contexts[contextIndex] + '主题·' + bases[baseIndex][0],
          contexts[contextIndex] + '主题·' + bases[baseIndex][1]]);
      }
    }
    return result;
  }

  public static drawWords(): string[] {
    const styles: string[] = [
      '戴围巾的', '会飞的', '正在唱歌的', '迷你', '巨大的', '彩色的', '困倦的', '开心的', '害羞的',
      '在月球上的', '撑雨伞的', '踩滑板的', '拿气球的', '看星星的', '在野餐的', '会发光的',
      '穿雨靴的', '在跳舞的', '背书包的', '正在冲浪的'
    ];
    const subjects: string[] = [
      '企鹅', '长颈鹿', '宇航员', '机器人', '海豚', '猫咪', '熊猫', '蜗牛', '鲸鱼',
      '向日葵', '热气球', '小火车', '灯塔', '城堡', '咖啡杯', '闹钟', '帆船', '仙人掌'
    ];
    return BuiltInContent.combine(styles, subjects, '');
  }

  public static charadesWords(): string[] {
    const actions: string[] = [
      '小心翼翼地', '兴高采烈地', '慢动作', '闭着眼睛', '踮着脚', '手忙脚乱地', '假装第一次',
      '像机器人一样', '像企鹅一样', '在大风里', '在失重状态下', '边唱边', '一边打电话一边',
      '用夸张表情', '偷偷摸摸地', '非常自信地', '困得睁不开眼地', '比赛般快速', '反复确认后', '突然开始'
    ];
    const scenes: string[] = [
      '挤地铁', '打篮球', '煮火锅', '拍毕业照', '找钥匙', '拆快递', '赶作业', '堆雪人',
      '放风筝', '学游泳', '做蛋糕', '搭帐篷', '弹吉他', '追公交', '整理书包', '给植物浇水'
    ];
    return BuiltInContent.combine(actions, scenes, '');
  }

  public static truthQuestions(): string[] {
    const stems: string[] = [
      '分享一次关于', '说出你最欣赏的', '如果重新选择一次关于', '描述你第一次接触', '说出你对',
      '讲一个发生在', '说出你想改变的', '分享你最近学到的', '说出你曾误解的', '描述最难忘的',
      '说出你愿意推荐的', '分享你对未来', '说出让你微笑的', '描述你坚持最久的', '说出你下一步想尝试的'
    ];
    const topics: string[] = [
      '友情', '旅行', '学习', '勇气', '美食', '音乐', '电影', '运动', '童年', '工作', '梦想', '习惯'
    ];
    return BuiltInContent.combine(stems, topics, '。');
  }

  public static dareChallenges(): string[] {
    const actions: string[] = [
      '用十秒钟表演', '即兴编一句广告词介绍', '闭眼画出', '用三种语气说出', '只用动作表达',
      '给右边玩家演示', '用播音腔描述', '模仿纪录片旁白介绍', '把它编进四句故事：', '用反义词猜出',
      '在十五秒内说出五个关于', '用手势教大家', '设计一个庆祝动作送给', '假装正在直播讲解', '用一句押韵的话赞美'
    ];
    const topics: string[] = [
      '猫咪', '早餐', '下雨', '考试', '旅行', '篮球', '朋友', '机器人', '夏天', '火锅', '星空', '周末'
    ];
    return BuiltInContent.combine(actions, topics, '。');
  }

  public static werewolfSetups(): string[] {
    return [
      '6人：狼人×2、预言家、女巫、村民×2',
      '7人：狼人×2、预言家、女巫、猎人、村民×2',
      '8人：狼人×2、预言家、女巫、猎人、守卫、村民×2',
      '9人：狼人×3、预言家、女巫、猎人、村民×3',
      '10人：狼人×3、预言家、女巫、猎人、守卫、村民×3',
      '11人：狼人×3、预言家、女巫、猎人、守卫、村民×4',
      '12人：狼人×4、预言家、女巫、猎人、守卫、村民×4'
    ];
  }

  private static combine(first: string[], second: string[], suffix: string): string[] {
    const result: string[] = [];
    for (let firstIndex: number = 0; firstIndex < first.length; firstIndex += 1) {
      for (let secondIndex: number = 0; secondIndex < second.length; secondIndex += 1) {
        result.push(first[firstIndex] + second[secondIndex] + suffix);
      }
    }
    return result;
  }
}
